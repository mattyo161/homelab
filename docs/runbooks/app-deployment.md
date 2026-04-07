# Runbook: deploying and managing apps

This runbook covers first-time bootstrap, day-to-day ArgoCD operations, and troubleshooting for the homelab application stack. See [DDD 005](../design_decision_documents/005-app-deployment-strategy.md) and [DDD 006](../design_decision_documents/006-argocd-for-app-management.md) for the rationale behind this approach.

## Two-layer model

**Ansible manages:** MetalLB, cert-manager, Traefik, Longhorn, and the initial ArgoCD bootstrap. Run `apps.yml` to install or upgrade these.

**ArgoCD manages:** All other applications (Prometheus stack, Headlamp, and anything added later). Push to git to deploy or upgrade these.

---

## Prerequisites

### Controller machine

```bash
# Helm
brew install helm

# ArgoCD CLI
brew install argocd

# kubernetes.core Ansible collection
ansible-galaxy collection install -r ansible/collections/requirements.yml

# Verify kubectl is configured correctly
kubectl cluster-info
kubectl get nodes
```

### Before first run: disable built-in k3s Traefik

k3s ships Traefik v2 via an internal `HelmChart` CR. Running both would cause port conflicts on 80/443.

Add to `ansible/inventory/group_vars/k3s_cluster/main.yml`:

```yaml
k3s_server_config:
  disable:
    - traefik
```

Apply:

```bash
ansible-playbook -i inventory/hosts.yml site.yml
kubectl get pods -n kube-system | grep traefik   # should return nothing
```

### Update the repo URL in App of Apps

Edit `apps/argocd/app-of-apps.yml` and set `spec.source.repoURL` to your actual GitHub repo URL before running `apps.yml`. This is what ArgoCD uses to watch for changes.

```yaml
spec:
  source:
    repoURL: https://github.com/<your-username>/homelab.git
```

Also update the same URL in each `apps/argocd/apps/*.yml` file under `sources:`.

---

## First-time bootstrap

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml apps.yml
```

This runs in order: open-iscsi on nodes → namespaces → MetalLB → cert-manager → Traefik → Longhorn → ArgoCD → App of Apps. Expect 20-30 minutes on first run.

At the end, the playbook prints:
- The ArgoCD initial admin password
- `argocd login` instructions

After ArgoCD is running, it will immediately begin syncing the applications in `apps/argocd/apps/` from git. Watch sync progress:

```bash
# Via CLI
argocd login argocd.oue.home
argocd app list

# Via browser
open https://argocd.oue.home
```

### Change the ArgoCD admin password

```bash
argocd login argocd.oue.home --username admin
argocd account update-password
```

---

## DNS setup

Find the Traefik LoadBalancer IP:

```bash
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Expected: 192.168.5.200
```

Add to Pi-hole:

```
k3s.oue.home        A      192.168.5.200
argocd.oue.home     CNAME  k3s.oue.home
grafana.oue.home    CNAME  k3s.oue.home
prometheus.oue.home CNAME  k3s.oue.home
headlamp.oue.home   CNAME  k3s.oue.home
traefik.oue.home    CNAME  k3s.oue.home
longhorn.oue.home   CNAME  k3s.oue.home
```

---

## Trust the self-signed CA

cert-manager created a private CA. Install it once in your browser/OS trust store so all HTTPS pages show green.

```bash
kubectl get secret -n cert-manager selfsigned-ca-secret \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > ~/homelab-ca.crt

# macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ~/homelab-ca.crt
# Then restart your browser
```

Firefox uses its own trust store: Settings → Privacy & Security → View Certificates → Authorities → Import → select `homelab-ca.crt` → Trust for websites.

---

## App URLs

| App | URL | Credentials |
|-----|-----|-------------|
| ArgoCD | https://argocd.oue.home | admin / printed by apps.yml |
| Grafana | https://grafana.oue.home | admin / `vault_grafana_admin_password` |
| Prometheus | https://prometheus.oue.home | none |
| Traefik dashboard | https://traefik.oue.home/dashboard/ | none (note trailing slash) |
| Longhorn UI | https://longhorn.oue.home | none |
| Headlamp | https://headlamp.oue.home | token (see below) |

### Headlamp token

```bash
kubectl get secret -n headlamp headlamp-admin-token \
  -o jsonpath='{.data.token}' | base64 -d
```

---

## Day-to-day: deploying and upgrading apps

### Upgrading an ArgoCD-managed app (Prometheus, Headlamp, etc.)

1. Update the chart version in `apps/argocd/apps/<app>.yml` (`targetRevision:`)
2. Or update values in `apps/<app>/values.yml`
3. Commit and push to git
4. ArgoCD detects the change within ~3 minutes and syncs automatically

To trigger sync immediately without waiting:

```bash
argocd app sync prometheus-stack
argocd app sync headlamp
```

### Upgrading an Ansible-managed infrastructure component (MetalLB, Traefik, cert-manager, Longhorn)

```bash
# Upgrade a specific component
ansible-playbook -i inventory/hosts.yml apps.yml --tags traefik
ansible-playbook -i inventory/hosts.yml apps.yml --tags metallb
ansible-playbook -i inventory/hosts.yml apps.yml --tags longhorn

# Upgrade all infrastructure
ansible-playbook -i inventory/hosts.yml apps.yml
```

### Adding a new app

1. Create `apps/<app-name>/values.yml` with Helm values overrides
2. Create `apps/argocd/apps/<app-name>.yml` with the ArgoCD Application manifest (copy an existing one as template)
3. Commit and push — ArgoCD's App of Apps will detect the new file and create the Application

---

## ArgoCD CLI reference

```bash
# Login
argocd login argocd.oue.home

# List all apps and sync status
argocd app list

# Get details on a specific app
argocd app get prometheus-stack

# Sync immediately (don't wait for the 3-minute poll interval)
argocd app sync prometheus-stack

# Sync all apps
argocd app sync --all

# Watch sync progress
argocd app wait prometheus-stack --sync

# Roll back to a previous revision
argocd app rollback prometheus-stack <revision-number>
argocd app history prometheus-stack   # to find revision numbers

# Pause auto-sync (make a manual change without ArgoCD reverting it)
argocd app set prometheus-stack --sync-policy none

# Re-enable auto-sync
argocd app set prometheus-stack --sync-policy automated

# Delete an app (and its resources, because of the finalizer)
argocd app delete headlamp
```

---

## Troubleshooting

### ArgoCD shows an app as OutOfSync

```bash
argocd app get <app-name>    # shows which resources differ
argocd app diff <app-name>   # shows the diff (like kubectl diff)
argocd app sync <app-name>   # force sync
```

Common causes:
- Chart has server-side default fields that differ from the manifest (use `ServerSideApply=true` syncOption)
- Values file references a secret that doesn't exist yet
- Network issue prevented the last sync from completing

### ArgoCD can't reach the git repo

```bash
# Check repo connection
argocd repo list

# If repo shows error, re-add credentials
argocd repo add https://github.com/mattyo161/homelab.git
```

For a private repo, add a personal access token:

```bash
argocd repo add https://github.com/mattyo161/homelab.git \
  --username <github-username> \
  --password <github-token>
```

### App is Degraded / pod not starting

```bash
# Check ArgoCD's view of the app
argocd app get prometheus-stack --show-conditions

# Check pods directly
kubectl get pods -n monitoring
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

### Certificate not issued

```bash
kubectl get certificate -A
kubectl describe certificate -n monitoring grafana-tls
kubectl logs -n cert-manager deploy/cert-manager
```

### Traefik not routing

```bash
kubectl get ingress -A
kubectl get ingressroute -A
kubectl logs -n traefik deploy/traefik
```

### Longhorn volumes stuck Pending

```bash
# Check open-iscsi on all nodes
ansible k3s_cluster -i inventory/hosts.yml -b -a 'systemctl status iscsid'

kubectl get pods -n longhorn-system
kubectl get pvc -A
```

### Infrastructure component not responding after Ansible upgrade

```bash
helm list -A
helm history <release-name> -n <namespace>    # see upgrade history
helm rollback <release-name> -n <namespace>   # rollback to previous
```

---

## References

- [DDD 005 — App deployment strategy](../design_decision_documents/005-app-deployment-strategy.md)
- [DDD 006 — ArgoCD for app management](../design_decision_documents/006-argocd-for-app-management.md)
- [DDD 004 — /etc/hosts for HA cluster endpoint](../design_decision_documents/004-etc-hosts-for-ha-cluster-endpoint.md)
- [CLI tools reference](cli-tools-reference.md)
- [apps/README.md](../../apps/README.md)
