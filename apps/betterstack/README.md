# BetterStack Integration Runbook

Covers three BetterStack products deployed to the homelab k3s cluster via ArgoCD:

| Product | What it does | ArgoCD App |
|---|---|---|
| **Logs** | Vector DaemonSet ships pod logs to BetterStack Logs | `betterstack-logs` |
| **Uptime** | Private location runner monitors internal `oue.home` services | `betterstack-uptime` |
| **Metrics** | Prometheus remote_write ships cluster metrics to BetterStack Telemetry | _(via prometheus-stack)_ |

---

## Prerequisites

- Cluster bootstrapped (`ansible-playbook ansible/apps.yml`)
- ArgoCD running and app-of-apps syncing
- BetterStack account with Logs, Uptime, and Telemetry products enabled

---

## First-time setup

### Step 1 — Collect tokens from BetterStack

| Ansible variable | Where to find it in BetterStack |
|---|---|
| `betterstack_logs_token` | Logs → Sources → Create source → copy **Source token** |
| `betterstack_uptime_api_key` | Uptime → Private Locations → New location → copy **API key** |
| `betterstack_telemetry_token` | Telemetry → Connect → copy **Bearer token** |

### Step 2 — Store tokens in ansible-vault

```bash
ansible-vault edit ansible/inventory/group_vars/k3s_cluster/vault.yml
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
git add apps/argocd/apps/betterstack-*.yml apps/betterstack/ apps/prometheus-stack/values.yml ansible/apps.yml
git commit -m "feat: add betterstack logs, uptime, and metrics integration"
git push
```

### Step 4 — Create secrets in the cluster

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/apps.yml \
  --tags betterstack-secrets \
  --ask-vault-pass
```

This creates two Kubernetes Secrets:

| Secret | Namespace | Keys |
|---|---|---|
| `betterstack-credentials` | `betterstack` | `logs-token`, `uptime-api-key` |
| `betterstack-telemetry` | `monitoring` | `bearerToken` |

### Step 5 — Verify ArgoCD sync

ArgoCD detects the new Application manifests automatically. Check status:

```bash
argocd app list
argocd app get betterstack-logs
argocd app get betterstack-uptime
```

Or open the ArgoCD UI at `https://argocd.oue.home`.

---

## File layout

```
apps/betterstack/
  logs-values.yml          # Vector Helm values (log shipping config)
  uptime/
    deployment.yml         # Private location agent Deployment
  README.md                # This file

apps/argocd/apps/
  betterstack-logs.yml     # ArgoCD Application — Vector (Helm)
  betterstack-uptime.yml   # ArgoCD Application — private location runner (raw manifests)
```

Metrics have no separate ArgoCD app — the `remoteWrite` block is added directly to
`apps/prometheus-stack/values.yml` and prometheus-stack re-syncs.

---

## Rotating a token

1. Update the value in `vault.yml`:
   ```bash
   ansible-vault edit ansible/inventory/group_vars/k3s_cluster/vault.yml
   ```

2. Re-run the secrets task:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/apps.yml \
     --tags betterstack-secrets \
     --ask-vault-pass
   ```

3. Restart the affected pod to pick up the new secret value:
   ```bash
   # Logs
   kubectl rollout restart daemonset/betterstack-logs-vector -n betterstack

   # Uptime
   kubectl rollout restart deployment/betterstack-uptime-agent -n betterstack

   # Metrics — Prometheus reloads config automatically on secret change
   ```

---

## Troubleshooting

### Logs not appearing in BetterStack

```bash
# Check Vector pod status
kubectl get pods -n betterstack

# Tail Vector logs for errors
kubectl logs -n betterstack -l app.kubernetes.io/name=vector --tail=50

# Confirm secret exists and has the right key
kubectl get secret betterstack-credentials -n betterstack -o jsonpath='{.data.logs-token}' | base64 -d
```

Common causes: wrong source token, incorrect BetterStack ingestion URL, Vector pod crashlooping.

### Uptime agent not connecting

```bash
kubectl logs -n betterstack deployment/betterstack-uptime-agent

# Verify secret
kubectl get secret betterstack-credentials -n betterstack -o jsonpath='{.data.uptime-api-key}' | base64 -d
```

Check BetterStack UI → Uptime → Private Locations to confirm the agent shows as connected.

### Metrics not appearing in BetterStack Telemetry

```bash
# Check Prometheus remote_write errors
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100 | grep -i "remote"

# Verify the telemetry secret exists in the monitoring namespace
kubectl get secret betterstack-telemetry -n monitoring
```

Common cause: secret in wrong namespace (`betterstack-telemetry` must be in `monitoring`, not `betterstack`).

### ArgoCD app stuck in OutOfSync

```bash
argocd app sync betterstack-logs
argocd app sync betterstack-uptime
```

If the app errors because the secret doesn't exist yet, run Step 4 first, then re-sync.

---

## Version pinning

Check and update these periodically:

| Component | File | Field | Current |
|---|---|---|---|
| Vector Helm chart | `apps/argocd/apps/betterstack-logs.yml` | `targetRevision` | `0.36.0` |
| Uptime agent image | `apps/betterstack/uptime/deployment.yml` | `image` | `betterstack/uptime-agent:latest` |

```bash
# Check latest Vector chart version
helm repo add vector https://helm.vector.dev
helm search repo vector/vector
```
