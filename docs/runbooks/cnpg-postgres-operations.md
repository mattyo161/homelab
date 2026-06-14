# Runbook: managing in-cluster PostgreSQL (CloudNativePG)

How to connect to, inspect, and operate the PostgreSQL databases that run
in-cluster via the **CloudNativePG (CNPG) operator**. The concrete example
throughout is the **traffinator** database; the same commands apply to any CNPG
`Cluster` — substitute the cluster name and namespace.

## Overview

- The **CNPG operator** (app `cnpg-operator`, namespace `cnpg-system`) manages
  PostgreSQL `Cluster` resources across all namespaces.
- Traffinator's DB is a `Cluster` named **`traffinator-postgres`** in the
  **`traffinator`** namespace — 2 HA instances (1 primary, 1 streaming
  replica) on Longhorn. It is declared by the traffinator Helm chart
  (`postgres.mode: cnpg` in `apps/traffinator/values.yml`), **not** by a raw
  manifest in this repo.
- CNPG creates three Services per cluster:
  | Service | Routes to | Use |
  |---------|-----------|-----|
  | `<cluster>-rw` | the **primary** (read-write) | interactive work, the app |
  | `<cluster>-ro` | **replicas** (read-only) | read-only queries |
  | `<cluster>-r`  | **any** instance | round-robin reads |
- CNPG also creates a `<cluster>-app` Secret (e.g. `traffinator-postgres-app`)
  holding the app role's credentials and ready-to-use connection strings. The
  traffinator backend reads `DATABASE_URL` from this secret's `uri` key
  automatically.

> The app/Django secrets (DJANGO_SECRET_KEY, API keys) are separate — created by
> `ansible/apps.yml` (tag `traffinator-secrets`). The DB credentials are owned
> by CNPG. See [the branch-testing runbook](testing-changes-on-a-branch.md) for
> the GitOps change flow.

## Find the primary

The primary can change after a failover/switchover — always resolve it:

```bash
kubectl get cluster traffinator-postgres -n traffinator \
  -o jsonpath='{.status.currentPrimary}{"\n"}'
```

## Open an interactive psql session

Run these in your own shell (in Claude Code, prefix with `!` so the interactive
session attaches to your terminal).

### A — superuser via exec (quickest, no password)

Peer auth on the pod's local socket lets `postgres` in without a password:

```bash
kubectl exec -it -n traffinator \
  "$(kubectl get cluster traffinator-postgres -n traffinator -o jsonpath='{.status.currentPrimary}')" \
  -c postgres -- psql -U postgres -d commute
```

### B — as the app role (`commute`), to see exactly what the app sees

The app role can't use peer auth, so connect over TCP with its password:

```bash
kubectl exec -it -n traffinator \
  "$(kubectl get cluster traffinator-postgres -n traffinator -o jsonpath='{.status.currentPrimary}')" \
  -c postgres -- env PGPASSWORD="$(kubectl get secret traffinator-postgres-app -n traffinator -o jsonpath='{.data.password}' | base64 -d)" \
  psql -h 127.0.0.1 -U commute -d commute
```

### C — your local psql / GUI against the cluster DB (port-forward)

Map to local port **5433** to avoid clashing with a local Postgres on 5432:

```bash
# terminal 1 — leave running
kubectl port-forward -n traffinator svc/traffinator-postgres-rw 5433:5432

# terminal 2
PGPASSWORD="$(kubectl get secret traffinator-postgres-app -n traffinator -o jsonpath='{.data.password}' | base64 -d)" \
  psql -h localhost -p 5433 -U commute -d commute
```

> Common gotcha: a `\dt` that's "missing tables" usually means you're connected
> to your **local** Postgres, not the cluster. Confirm with
> `SELECT inet_server_addr(), current_database();`.

### D — the CNPG kubectl plugin (nicest, if installed)

```bash
kubectl krew install cnpg          # one-time
kubectl cnpg psql    traffinator-postgres -n traffinator   # primary, as superuser
kubectl cnpg status  traffinator-postgres -n traffinator   # health, instances, lag
```

## Inspect health & topology

```bash
# Cluster summary: instances, ready count, primary, phase
kubectl get cluster traffinator-postgres -n traffinator

# Pods (primary + replicas) and their PVCs
kubectl get pods,pvc -n traffinator -l cnpg.io/cluster=traffinator-postgres

# Rich status (if the cnpg plugin is installed): replication lag, failover history
kubectl cnpg status traffinator-postgres -n traffinator
```

## Connection details (without opening psql)

The `<cluster>-app` Secret carries everything; keys include `username`,
`password`, `dbname`, `host`, `port`, `uri`, `jdbc-uri`, `pgpass`:

```bash
# Full connection URI the backend uses
kubectl get secret traffinator-postgres-app -n traffinator \
  -o jsonpath='{.data.uri}' | base64 -d; echo
```

## pgAudit (session auditing)

Enabled via `postgres.cnpg.pgaudit` in `apps/traffinator/values.yml`
(`pgaudit.log: "write,ddl,role"`). Audited statements are written to the
Postgres log as **structured JSON** (`"logger":"pgaudit"`, with a nested
`audit` object), shipped by Vector to Loki/BetterStack.

```bash
# Tail audit records straight from the primary
kubectl logs -n traffinator \
  "$(kubectl get cluster traffinator-postgres -n traffinator -o jsonpath='{.status.currentPrimary}')" \
  -c postgres -f | grep pgaudit
```

In Grafana → Explore (Loki), parse the JSON:

```logql
{namespace="traffinator", container="postgres"} | json | logger="pgaudit"
{namespace="traffinator", container="postgres"} | json | record_audit_class="WRITE"
```

There's a prebuilt **Traffinator — pgAudit** dashboard (Grafana folder
*Traffinator*). Notes:
- `pgaudit.log` filters by statement **class** (write/ddl/role/...), not by
  table — you can't exclude a single noisy table (e.g. the Django DB cache
  `commute_cache`) via pgaudit config. Filter in Vector before the sinks, or
  move that workload off Postgres, if the volume is a problem.
- `CREATE EXTENSION pgaudit` runs only at first cluster bootstrap. Session
  logging works from `shared_preload_libraries` + the GUC regardless; the
  extension is only needed for object-level (`pgaudit.role`) auditing.

## Metrics

CNPG exposes a Prometheus exporter; `postgres.cnpg.monitoring.enablePodMonitor:
true` creates a PodMonitor. Prometheus scrapes it because the monitor selectors
are relaxed (`*SelectorNilUsesHelmValues: false` in
`apps/prometheus-stack/values.yml`) — CNPG's PodMonitor doesn't carry the
`release: prometheus-stack` label.

```promql
cnpg_collector_up{namespace="traffinator"}
cnpg_pg_database_size_bytes{datname="commute"}
cnpg_backends_total{namespace="traffinator"}
```

Prebuilt **CloudNativePG** dashboard lives in Grafana folder *Databases*.

## Common operations

All persistent config changes are GitOps — edit
`apps/traffinator/values.yml`, open a PR, let ArgoCD sync. Don't `kubectl edit`
the Cluster directly (selfHeal reverts it). To test before merging, see
[testing-changes-on-a-branch.md](testing-changes-on-a-branch.md).

- **Change PG parameters / extensions / pgaudit** — edit `postgres.cnpg.*` in
  values. CNPG applies it; changes to `shared_preload_libraries` trigger a
  **rolling restart** (HA, stays available).
- **Scale instances (HA)** — change `postgres.cnpg.instances`. Going `1 -> 2`
  adds a streaming replica.
- **Manual switchover** (move the primary, e.g. to drain a node):
  ```bash
  kubectl cnpg promote traffinator-postgres <target-instance> -n traffinator
  ```
- **Restart**:
  ```bash
  kubectl cnpg restart traffinator-postgres -n traffinator
  ```
- **Storage size is grow-only** and depends on the StorageClass supporting
  volume expansion (Longhorn does). Shrinking requires a new cluster + restore.

## Caveats

| Symptom | Cause | Fix |
|---------|-------|-----|
| `\dt` missing tables | Connected to a **local** Postgres, not the cluster | Verify with `SELECT inet_server_addr()`; use option A–D above |
| App can't connect after cutover | `traffinator-postgres-app` secret / `DATABASE_URL` not yet present | Wait for CNPG to create the `-app` secret; backend retries |
| pgaudit logs absent | Library loaded but no audited activity | Only `write,ddl,role` classes are audited — plain `SELECT` isn't |
| CNPG metrics not in Prometheus | PodMonitor lacks `release: prometheus-stack` | Already handled by the relaxed selectors; don't re-tighten them |
| Switching `mode: cnpg` ⇄ `bundled` | Prunes the other's storage | **Fresh/empty DB** — migrate with `pg_dump`/restore if data matters |
