# Loki

Local log aggregation for the homelab cluster. Stores pod logs on Longhorn and queries them from Grafana.

- **Docs:** https://grafana.com/docs/loki/latest/
- **Helm chart:** https://grafana.github.io/helm-charts
- **Query UI:** https://grafana.oue.home → Explore → Loki

## Architecture

```
Pod logs → Vector DaemonSet (betterstack namespace) → Loki (monitoring) → Grafana Explore
                                              └──► BetterStack Logs (filtered subset)
```

Vector ships **all** pod logs to Loki with no namespace or level filtering. The BetterStack sink uses a separate filtered path — see `apps/betterstack/README.md`.

## Managed by

ArgoCD (`apps/argocd/apps/loki.yml`).

Before first sync, register the Helm repo in ArgoCD:

```bash
argocd repo add https://grafana.github.io/helm-charts --type helm --name grafana
```

## Validate

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=loki
kubectl -n monitoring get svc loki

# Ready check
kubectl -n monitoring run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl -sS http://loki.monitoring.svc.cluster.local:3100/ready
```

## Query examples (Grafana Explore)

```logql
# All logs from a namespace
{namespace="gitlab"}

# Longhorn warnings and errors
{namespace="longhorn-system"} |~ "(?i)warn|error|fail|degraded"

# A specific pod
{namespace="gitlab", pod=~"gitlab-webservice.*"}

# Filter info locally in LogQL (Loki receives all levels)
{namespace="gitlab"} != "info"
```

## Tuning

Edit `apps/loki/values.yml`:

| Setting | Default | Purpose |
|---------|---------|---------|
| `limits_config.retention_period` | `168h` | How long logs are kept |
| `singleBinary.persistence.size` | `20Gi` | Longhorn PVC size |
| `singleBinary.resources` | 256Mi–1Gi | Memory for ingestion/query |

BetterStack-only filters (namespace exclusions, info-level drops) live in `apps/betterstack/logs-values.yml` under the `filter_noise` transform.
