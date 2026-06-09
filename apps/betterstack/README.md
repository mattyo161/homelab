# BetterStack Integration Runbook

Covers BetterStack products and cluster log shipping for the homelab k3s cluster via ArgoCD.

| Product | What it does | ArgoCD App |
|---|---|---|
| **Logs (BetterStack)** | Vector ships filtered pod logs to BetterStack Logs (cloud) | `betterstack-logs` |
| **Logs (Loki)** | Vector ships all pod logs to in-cluster Loki → Grafana Explore | `betterstack-logs` + `loki` |
| **Uptime** | Private location runner monitors internal `oue.home` services | `betterstack-uptime` |
| **Metrics** | Prometheus remote_write ships cluster metrics to BetterStack Telemetry | _(via prometheus-stack)_ |

## Log shipping architecture

```
kubernetes_logs
      │
      ▼
 add_cluster_meta  ──────────────────►  Loki (all logs, no filter)
      │
      ▼
 filter_noise      ──────────────────►  BetterStack (filtered — saves quota)
```

Vector config: `apps/betterstack/logs-values.yml`

| Destination | Input transform | Filtering |
|---|---|---|
| **Loki** | `add_cluster_meta` | None — all pod logs |
| **BetterStack** | `filter_noise` | Namespace exclusions + drops `info` level |

Query Loki locally at https://grafana.oue.home → Explore → Loki. See `apps/loki/README.md`.

---

## Prerequisites

- Cluster bootstrapped (`ansible-playbook ansible/apps.yml`)
- ArgoCD running and app-of-apps syncing
- BetterStack account with Logs, Uptime, and Telemetry products enabled
- Loki deployed (`apps/argocd/apps/loki.yml`)

---

## First-time setup

### Step 1 — Collect tokens from BetterStack

| Ansible variable | Where to find it in BetterStack |
|---|---|
| `betterstack_logs_token` | Logs → Sources → Create source → copy **Source token** |
| `betterstack_telemetry_token` | Telemetry → Connect → copy **Bearer token** |
| `betterstack_heartbeat_argocd_url` | Uptime → Heartbeat monitors → New monitor (period: 2m, grace: 1m) → copy **Heartbeat URL** |

### Step 2 — Store tokens in ansible-vault

```bash
ansible-vault edit ansible/inventory/group_vars/all/vault.yml
```

Add:

```yaml
betterstack_logs_token: "your-logs-source-token"
betterstack_uptime_api_key: "your-private-location-api-key"
betterstack_telemetry_token: "your-telemetry-bearer-token"
```

### Step 3 — Push the config to git

ArgoCD reads manifests from git, so the files must be present before the secrets are created.

```bash
git add apps/argocd/apps/betterstack-*.yml apps/argocd/apps/loki.yml \
  apps/betterstack/ apps/loki/ apps/prometheus-stack/values.yml ansible/apps.yml
git commit -m "feat: add betterstack and loki log shipping"
git push
```

### Step 4 — Create secrets in the cluster

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/apps.yml \
  --tags betterstack-secrets \
  --ask-vault-pass
```

| Secret | Namespace | Keys |
|---|---|---|
| `betterstack-credentials` | `betterstack` | `BETTERSTACK_LOGS_TOKEN` |
| `betterstack-heartbeats` | `betterstack` | `ARGOCD_HEARTBEAT_URL` (one key per monitored service) |
| `betterstack-telemetry` | `monitoring` | `bearerToken` |

### Step 5 — Verify ArgoCD sync

```bash
argocd app list
argocd app get loki
argocd app get betterstack-logs
argocd app get betterstack-uptime
```

Or open the ArgoCD UI at `https://argocd.oue.home`.

---

## File layout

```
apps/betterstack/
  logs-values.yml          # Vector Helm values (dual Loki + BetterStack sinks)
  uptime/
    deployment.yml         # Private location agent Deployment
  README.md                # This file

apps/loki/
  values.yml               # Loki Helm values (log storage)

apps/argocd/apps/
  betterstack-logs.yml     # ArgoCD Application — Vector (Helm)
  betterstack-uptime.yml   # ArgoCD Application — private location runner
  loki.yml                 # ArgoCD Application — Loki (Helm)
```

Metrics have no separate ArgoCD app — the `remoteWrite` block is added directly to
`apps/prometheus-stack/values.yml` and prometheus-stack re-syncs.

---

## Adding a new heartbeat monitor

To monitor another internal service (e.g. Grafana):

1. In BetterStack Uptime → Heartbeat monitors, create a new monitor (period: 2m, grace: 1m). Copy the heartbeat URL.

2. Add to vault:
   ```bash
   ansible-vault edit ansible/inventory/group_vars/all/vault.yml
   # add: betterstack_heartbeat_grafana_url: "https://uptime.betterstack.com/api/v1/heartbeat/<token>"
   ```

3. Add the key to the `betterstack-heartbeats` secret in `ansible/apps.yml`:
   ```yaml
   GRAFANA_HEARTBEAT_URL: "{{ betterstack_heartbeat_grafana_url }}"
   ```

4. Copy the CronJob in `apps/betterstack/uptime/deployment.yml`, change `name`, `SERVICE_URL`, and the `secretKeyRef.key`.

5. Re-run secrets and push to git.

## Rotating a token

1. Update the value in `vault.yml`:
   ```bash
   ansible-vault edit ansible/inventory/group_vars/all/vault.yml
   ```

2. Re-run the secrets task:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/apps.yml \
     --tags betterstack-secrets \
     --ask-vault-pass
   ```

3. Restart the affected pod to pick up the new secret value:
   ```bash
   kubectl rollout restart daemonset/betterstack-logs-vector -n betterstack

   # Metrics — Prometheus reloads config automatically on secret change
   ```

---

## Querying logs locally (Loki)

1. Ensure Loki is synced: `argocd app get loki`
2. Open https://grafana.oue.home → **Explore** → datasource **Loki**
3. See `apps/loki/README.md` for LogQL examples

Loki receives **all** pod logs with no namespace or level filtering.

## Reducing BetterStack log volume

Filtering applies to the **BetterStack sink only** — Loki is unaffected.

Edit the `filter_noise` transform in `apps/betterstack/logs-values.yml`.

**Namespace filter** — add or remove namespaces from the exclusion list, or switch to an allowlist:

```yaml
condition: includes(["dev", "prod", "gitlab"], string!(.kubernetes.pod_namespace))
```

**Log level** — `filter_noise` drops `info` when the level is in a structured field (`.level`, `.severity`) or JSON message body. Unstructured lines without a detectable level still ship to BetterStack.

**Per-pod opt-out** — annotate a pod or deployment (applies to both sinks via the kubernetes_logs source):

```yaml
metadata:
  annotations:
    vector.dev/exclude: "true"
```

After changes, sync ArgoCD or restart Vector:

```bash
kubectl rollout restart daemonset/betterstack-logs-vector -n betterstack
```

---

## Troubleshooting

### Logs not appearing in BetterStack

```bash
kubectl get pods -n betterstack
kubectl logs -n betterstack -l app.kubernetes.io/name=vector --tail=50
kubectl get secret betterstack-credentials -n betterstack \
  -o jsonpath='{.data.BETTERSTACK_LOGS_TOKEN}' | base64 -d; echo
```

Common causes: wrong source token, quota exceeded (`402 Payment Required` in Vector logs), incorrect ingestion URL, Vector pod crashlooping.

### Logs not appearing in Loki

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=loki
kubectl logs -n betterstack -l app.kubernetes.io/name=vector --tail=50 | grep -i loki
kubectl -n monitoring run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl -sS http://loki.monitoring.svc.cluster.local:3100/ready
```

Common causes: Loki pod not running (check Longhorn PVC), Vector not synced after config change.

### Heartbeat CronJob not firing

```bash
kubectl get jobs -n betterstack
kubectl logs -n betterstack -l job-name --tail=20
kubectl get secret betterstack-heartbeats -n betterstack \
  -o jsonpath='{.data.ARGOCD_HEARTBEAT_URL}' | base64 -d
```

### Metrics not appearing in BetterStack Telemetry

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100 | grep -i "remote"
kubectl get secret betterstack-telemetry -n monitoring
```

Common cause: secret in wrong namespace (`betterstack-telemetry` must be in `monitoring`, not `betterstack`).

### ArgoCD app stuck in OutOfSync

```bash
argocd app sync loki
argocd app sync betterstack-logs
argocd app sync betterstack-uptime
```

---

## Version pinning

| Component | File | Field | Current |
|---|---|---|---|
| Vector Helm chart | `apps/argocd/apps/betterstack-logs.yml` | `targetRevision` | `0.36.0` |
| Loki Helm chart | `apps/argocd/apps/loki.yml` | `targetRevision` | `6.55.0` |
| Uptime agent image | `apps/betterstack/uptime/deployment.yml` | `image` | `betterstack/uptime-agent:latest` |

```bash
helm repo add vector https://helm.vector.dev
helm search repo vector/vector
helm repo add grafana https://grafana.github.io/helm-charts
helm search repo grafana/loki
```
