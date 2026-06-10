# GitLab on k3s Homelab

Deploys GitLab CE and GitLab Runner via ArgoCD, following the same
app-of-apps pattern used by prometheus-stack and headlamp.

## Architecture

```
ArgoCD
  ├── gitlab          → gitlab namespace       (Helm: gitlab/gitlab)
  └── gitlab-runner   → gitlab-runner namespace (Helm: gitlab/gitlab-runner)

GitLab core pods → mou-mini4 (affinity: role=gitlab)
Runner job pods  → mou-mini3, mou-mini5 (spreads across amd64 workers)
Storage          → Longhorn (all PVCs)
Ingress          → Traefik + cert-manager (selfsigned-cluster-issuer)
```

## Step 1 — Label and taint nodes

```bash
# Stateful GitLab components (Gitaly, PostgreSQL, MinIO, Redis) → mini4
# mini4 already runs Longhorn instance-manager so volume I/O stays local
kubectl label node mou-mini4 role=gitlab-storage

# Stateless GitLab components (Webservice, Sidekiq) → pc1
# pc1 has 3+ GiB free RAM and 4 CPUs, lightly loaded control plane
kubectl label node mou-pc1 role=gitlab-app

# Prevent GitLab images (amd64 only) from landing on the Pi
kubectl taint node mou-pi5 arch=arm64:NoSchedule
```

## Step 2 — Add GitLab Helm repo (for ArgoCD to resolve the chart)

ArgoCD needs the repo registered:

```bash
# If using ArgoCD CLI:
argocd repo add https://charts.gitlab.io/ --type helm --name gitlab

# Or via ArgoCD UI:
# Settings → Repositories → Connect Repo → Helm → https://charts.gitlab.io/
```

## Step 3 — Sync GitLab (NOT the runner yet)

Copy the ArgoCD manifests into your homelab repo:

```
apps/argocd/apps/gitlab.yml          ← copy from this directory
apps/argocd/apps/gitlab-runner.yml   ← copy but DON'T sync yet
apps/gitlab/values.yml               ← copy from this directory
apps/gitlab-runner/values.yml        ← copy from this directory
```

Push to git. ArgoCD will detect `gitlab.yml` via app-of-apps and begin syncing.

Watch progress:
```bash
kubectl get pods -n gitlab -w
# Takes 5-10 minutes. Normal to see Init and Pending states.
```

## Step 4 — Get the initial root password

```bash
kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab \
  -ojsonpath='{.data.password}' | base64 --decode; echo
```

Login at https://gitlab.oue.home with user `root` and that password.
Change it immediately.

## Step 5 — Register the runner

In GitLab UI:
1. Admin Area (wrench icon) → CI/CD → Runners → New instance runner
2. Check "Run untagged jobs"
3. Add tags: `privileged-runner,k3s-homelab`
4. Create runner → copy the token (starts with `glrt-`)

Create the Kubernetes secret:
```bash
kubectl create namespace gitlab-runner

kubectl create secret generic gitlab-runner-secret \
  --namespace gitlab-runner \
  --from-literal=runner-registration-token="" \
  --from-literal=runner-token="glrt-PASTE_YOUR_TOKEN_HERE"
```

## Step 6 — Wire runner cache to GitLab MinIO

```bash
# Get MinIO credentials from GitLab's secret
MINIO_ACCESS=$(kubectl get secret gitlab-minio-secret \
  -n gitlab -ojsonpath='{.data.accesskey}' | base64 -d)
MINIO_SECRET=$(kubectl get secret gitlab-minio-secret \
  -n gitlab -ojsonpath='{.data.secretkey}' | base64 -d)

kubectl create secret generic gitlab-minio-secret \
  --namespace gitlab-runner \
  --from-literal=accesskey="$MINIO_ACCESS" \
  --from-literal=secretkey="$MINIO_SECRET"
```

## Step 7 — Sync the runner

Add `apps/argocd/apps/gitlab-runner.yml` to your git push (or sync
manually from ArgoCD UI). The runner will register and appear in
Admin Area → CI/CD → Runners within ~60 seconds.

## Step 8 — Import k3s-ansible from GitHub

In GitLab UI: New Project → Import Project → GitHub
Select `mattyo161/k3s-ansible`, import `mou-latest` branch.
Set it as default branch in Project → Settings → Repository.

## Step 9 — Add Prometheus scraping for GitLab metrics

Add to `apps/prometheus-stack/values.yml`:

```yaml
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
      - job_name: gitlab
        metrics_path: /-/metrics
        scheme: https
        tls_config:
          insecure_skip_verify: true   # selfsigned cert
        static_configs:
          - targets: ['gitlab.oue.home']
```

## Verification commands

```bash
# All GitLab pods running
kubectl get pods -n gitlab

# Runner registered and idle
kubectl get pods -n gitlab-runner

# PVCs all bound (Longhorn provisioned storage)
kubectl get pvc -n gitlab

# Check which node pods landed on
kubectl get pods -n gitlab -o wide

# GitLab version
kubectl exec -n gitlab \
  $(kubectl get pod -n gitlab -l app=webservice -ojsonpath='{.items[0].metadata.name}') \
  -- cat /srv/gitlab/VERSION
```

## Troubleshooting

**Pods stuck in Pending:**
```bash
kubectl describe pod <pod-name> -n gitlab | grep -A10 Events
# Usually: PVC not bound, or affinity can't be satisfied
```

**PVC not binding:**
```bash
kubectl get pvc -n gitlab
kubectl describe pvc <pvc-name> -n gitlab
# Check Longhorn UI at longhorn.oue.home
```

**Runner not appearing in GitLab:**
```bash
kubectl logs -n gitlab-runner \
  $(kubectl get pod -n gitlab-runner -ojsonpath='{.items[0].metadata.name}')
# Usually: wrong token, or can't reach GitLab API from inside cluster
```

**TLS error: certificate valid for `*.traefik.default`, not `gitlab.oue.home`:**
The runner runs inside the cluster. It should use the internal GitLab Workhorse service, not the external Traefik ingress URL. `apps/gitlab-runner/values.yml` sets:

```
gitlabUrl: http://gitlab-webservice-default.gitlab.svc.cluster.local:8181
clone_url = "http://gitlab-webservice-default.gitlab.svc.cluster.local:8181"
```

Humans still use `https://gitlab.oue.home` in the browser. Only runner ↔ GitLab API traffic uses the internal URL.

Verify connectivity from a debug pod:
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n gitlab-runner -- \
  curl -sS -o /dev/null -w "%{http_code}\n" \
  http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/-/health
```
