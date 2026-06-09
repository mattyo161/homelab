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
| `betterstack_telemetry_token` | Telemetry → Connect → copy **Bearer token** |
| `betterstack_heartbeat_argocd_url` | Uptime → Heartbeat monitors → New monitor (period: 2m, grace: 1m) → copy **Heartbeat URL** |

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
| `betterstack-credentials` | `betterstack` | `BETTERSTACK_LOGS_TOKEN` |
| `betterstack-heartbeats` | `betterstack` | `ARGOCD_HEARTBEAT_URL` (one key per monitored service) |
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

## Adding a new heartbeat monitor

To monitor another internal service (e.g. Grafana):

1. In BetterStack Uptime → Heartbeat monitors, create a new monitor (period: 2m, grace: 1m). Copy the heartbeat URL.

2. Add to vault:
   ```bash
   ansible-vault edit ansible/inventory/group_vars/k3s_cluster/vault.yml
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

### Heartbeat CronJob not firing

```bash
# Check recent job runs
kubectl get jobs -n betterstack

# Check logs from the last heartbeat job
kubectl logs -n betterstack -l job-name --tail=20

# Verify the heartbeat secret exists
kubectl get secret betterstack-heartbeats -n betterstack -o jsonpath='{.data.ARGOCD_HEARTBEAT_URL}' | base64 -d
```

In BetterStack, the heartbeat monitor will show as down if the CronJob stops running or the service URL fails to respond.

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
