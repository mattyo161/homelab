# kube-prometheus-stack

kube-prometheus-stack bundles Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics with pre-built Kubernetes dashboards and alerting rules.

- **Docs:** https://prometheus-operator.dev/
- **Helm chart:** https://prometheus-community.github.io/helm-charts
- **GitHub:** https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

## Components

| Component | URL | Purpose |
|---|---|---|
| Grafana | https://grafana.oue.home | Dashboards, metrics, and log search (Loki datasource) |
| Prometheus | https://prometheus.oue.home | Metrics collection and querying |
| Loki | (internal) | Log storage — query via Grafana Explore |
| Alertmanager | (internal) | Alert routing and silencing |

## Managed by

ArgoCD (`apps/argocd/apps/prometheus-stack.yml`). To update: edit `apps/prometheus-stack/values.yml` or the chart version in `apps/argocd/apps/prometheus-stack.yml` and push to git.

## Validate it is running

```bash
# All pods should be Running
kubectl -n monitoring get pods

# Check PVCs for Prometheus and Grafana persistence (backed by Longhorn)
kubectl -n monitoring get pvc

# Check ingress
kubectl -n monitoring get ingress

# Check TLS certificates
kubectl -n monitoring get certificate
```

## Grafana

### Login

URL: https://grafana.oue.home

Default credentials:
- Username: `admin`
- Password: set via `grafana.adminPassword` in `apps/prometheus-stack/values.yml` (should be overridden via Ansible Vault)

### Reset admin password

```bash
kubectl -n monitoring exec -it deploy/prometheus-stack-grafana -- \
  grafana-cli admin reset-admin-password <newpassword>
```

### Get current admin password from the cluster secret

```bash
kubectl -n monitoring get secret prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

### Log search (Loki)

1. Open https://grafana.oue.home → **Explore**
2. Select the **Loki** datasource
3. Example queries:

```logql
{namespace="gitlab"}
{namespace="longhorn-system"} |~ "(?i)warn|error|fail|degraded"
{namespace="gitlab", pod=~"gitlab-webservice.*"}
```

Vector (`apps/betterstack/logs-values.yml`) ships all pod logs to Loki and a filtered subset to BetterStack. Loki config: `apps/loki/values.yml`.

## Prometheus

### Login

URL: https://prometheus.oue.home

No authentication by default. Access is controlled at the ingress/network level.

### Useful queries

```promql
# CPU usage per node
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage per node
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# Disk usage per node
(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100
```

## Get current Helm config

```bash
helm get values prometheus-stack -n monitoring
```

## Troubleshooting

```bash
# Check Prometheus operator logs
kubectl -n monitoring logs -l app.kubernetes.io/name=prometheus-operator --tail=50

# Check Prometheus pod logs
kubectl -n monitoring logs -l app.kubernetes.io/name=prometheus --tail=50

# Check Grafana logs
kubectl -n monitoring logs -l app.kubernetes.io/name=grafana --tail=50

# Check if ServiceMonitors are being picked up
kubectl get servicemonitor -A

# Check Prometheus targets (from the Prometheus UI)
# https://prometheus.oue.home/targets
```
