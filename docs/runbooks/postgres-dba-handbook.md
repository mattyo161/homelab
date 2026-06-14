# The PostgreSQL Handbook — a retiring DBA's notes

> I'm handing you the keys. You're comfortable on the command line and you can
> script, so I won't waste your time on basics. What follows is the stuff that
> isn't in the manual: the habits, the triage instincts, the security posture
> I stopped thinking about years ago because it's just *how you do it*, and the
> bookmarks that made me good at this. Read it once end-to-end, then keep it
> where you can find it at 3 a.m.
>
> Our databases run under **CloudNativePG** on k3s, observed by
> Prometheus/Loki/Grafana, audited by pgAudit. Commands here use the
> `traffinator-postgres` cluster as the example — see
> [cnpg-postgres-operations.md](cnpg-postgres-operations.md) for the connection
> mechanics. The *thinking* below is portable to any Postgres you'll ever run.

---

## 1. The mental model

Postgres almost never "just breaks." It degrades, and it tells you long before
it falls over — if you're listening. Your job isn't to react to "the database
is down"; it's to notice the **leading indicators** while everything still looks
green:

- **Connections creeping up** toward `max_connections`.
- **Transactions staying open** longer than they used to (idle-in-transaction is
  the silent killer — it pins locks and blocks vacuum).
- **Dead tuples accumulating** faster than autovacuum clears them.
- **Replication lag** trending up.
- **The oldest transaction age** (XID) marching toward wraparound.
- **Cache hit ratio** sliding as the working set outgrows RAM.

Everything in my daily routine exists to watch those six things. Master them and
you'll look like a wizard.

---

## 2. My daily routine

I run the same five-minute sweep every morning before I touch anything else.
Coffee, then this.

### 2.1 The cluster is healthy at the orchestration layer

```bash
kubectl get cluster -A                                   # all CNPG clusters
kubectl cnpg status traffinator-postgres -n traffinator  # primary, replicas, lag, failover history
```

I want: expected instance count, one primary, replicas streaming, no recent
unplanned failovers. A failover overnight is the first thing to explain.

### 2.2 The Grafana sweep (60 seconds)

I keep two dashboards pinned:
- **CloudNativePG** (folder *Databases*) — connections, TPS, cache hit ratio,
  replication lag, WAL, checkpoints, DB size.
- **Traffinator — pgAudit** (folder *Traffinator*) — who did what overnight.

I'm not reading numbers, I'm reading **shapes**. A sawtooth that grew a tooth, a
baseline that crept, a flat line that should be wiggling. Anomalies are
deviations from yesterday, not absolute thresholds.

### 2.3 The PromQL glance

```promql
# Connection headroom — alarm in my head if this trends past ~70%
sum(cnpg_backends_total) / on(pod) cnpg_pg_settings_setting{name="max_connections"}

# Replica lag in bytes
cnpg_pg_replication_lag

# Cache hit ratio (want > 0.99 for OLTP)
rate(cnpg_pg_stat_database_blks_hit[5m])
  / (rate(cnpg_pg_stat_database_blks_hit[5m]) + rate(cnpg_pg_stat_database_blks_read[5m]))

# Deadlocks and rollbacks — should be ~flat
rate(cnpg_pg_stat_database_deadlocks[5m])
```

### 2.4 The SQL back-pocket queries

These live in a `~/.psqlrc` as `\set` shortcuts so I can fire them blind. Keep
your own copy; you'll use them daily.

```sql
-- Who's connected and what state are they in?
SELECT state, count(*) FROM pg_stat_activity GROUP BY state ORDER BY 2 DESC;

-- Anything running longer than 1 minute? (the #1 incident query)
SELECT pid, now()-query_start AS runtime, state, wait_event_type, wait_event,
       left(query,80) AS query
FROM pg_stat_activity
WHERE state <> 'idle' AND now()-query_start > interval '1 minute'
ORDER BY runtime DESC;

-- Idle-in-transaction offenders (these block vacuum and hold locks)
SELECT pid, now()-xact_start AS tx_age, now()-state_change AS idle_for,
       left(query,80)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY tx_age DESC;

-- Who is blocking whom?
SELECT blocked.pid AS blocked_pid, blocking.pid AS blocking_pid,
       left(blocked.query,60) AS blocked_query,
       left(blocking.query,60) AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid));

-- Top time-consuming statements (needs pg_stat_statements)
SELECT calls, round(total_exec_time::numeric,1) AS total_ms,
       round(mean_exec_time::numeric,2) AS mean_ms, left(query,80)
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 15;

-- Table & index sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) AS total,
       pg_size_pretty(pg_relation_size(relid)) AS heap
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 20;

-- Dead tuples / autovacuum health
SELECT relname, n_live_tup, n_dead_tup,
       round(100*n_dead_tup/greatest(n_live_tup,1),1) AS dead_pct,
       last_autovacuum
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 20;

-- XID age — the thing that ends careers if ignored. Watch the trend.
SELECT datname, age(datfrozenxid) AS xid_age
FROM pg_database ORDER BY xid_age DESC;

-- Unused indexes (idx_scan = 0 → candidates for removal; they cost writes)
SELECT relname, indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY pg_relation_size(indexrelid) DESC;
```

If those all look like yesterday, I close the laptop and trust the alerts.

---

## 3. Incident triage — the playbook

When something's wrong, resist the urge to *do* something. Diagnose in order;
each step narrows it. The cardinal rule: **never `kill -9` a backend** — use
`pg_terminate_backend(pid)` (or `pg_cancel_backend` to just cancel the query).

### Step 0 — Is it even the database?

Half of "the DB is slow" tickets are the app, the network, or DNS. Check
app-side latency and error rates first. From the DB side:

```sql
SELECT count(*) FROM pg_stat_activity;          -- connection count vs max
SHOW max_connections;
```

If connections are pinned at max, the app can't get a connection — that *looks*
like "DB down" but it's a pooling/leak problem (see §5).

### Step 1 — Active load: what's running right now?

Run the "longer than 1 minute" query from §2.4. You're looking for:
- One **long query** hammering the box → `EXPLAIN (ANALYZE, BUFFERS)` it later;
  for now decide whether to `pg_cancel_backend`.
- A **lock pileup** → run the blocking query. Kill the *root* blocker, not the
  victims.
- Many copies of the **same** query → missing index or a bad deploy.

### Step 2 — Waits: what are they waiting on?

`wait_event_type`/`wait_event` in `pg_stat_activity` tells you the bottleneck:
- `Lock` → contention; chase the blocker.
- `IO` / `DataFileRead` → working set exceeds RAM, or a runaway seq scan.
- `LWLock` → internal contention (often checkpoint or buffer pressure).
- `Client` → it's waiting on the *app*, not the DB.

### Step 3 — Resources: disk, memory, WAL

```bash
# Disk on the data volume (full disk = read-only DB = outage)
kubectl exec -n traffinator <primary> -c postgres -- df -h /var/lib/postgresql/data
```

Disk-full is usually one of: WAL not being archived/recycled, a **replication
slot with no consumer** holding WAL forever (check `pg_replication_slots` for
`active = false` with growing `restart_lsn` distance), or runaway bloat. WAL
explosions also come from long transactions preventing checkpoint cleanup.

### Step 4 — Replication

```sql
-- On the primary:
SELECT application_name, state, write_lag, flush_lag, replay_lag
FROM pg_stat_replication;
```

Lag climbing → replica can't keep up (I/O, a long query on the replica blocking
replay, or network). With CNPG, `kubectl cnpg status` summarizes this and the
operator handles failover; your job is to find *why*.

### Step 5 — After the fire: root cause

Once stable, capture evidence before it rolls out of the logs:
- `EXPLAIN (ANALYZE, BUFFERS)` the offending query; paste into
  explain.dalibo.com or pgMustard.
- Pull the pgAudit/Postgres logs from Loki around the incident window.
- Check `pg_stat_statements` for the query's history.
- Write it down. The post-mortem you skip is the incident you repeat.

---

## 4. Maintenance habits

The boring work that prevents the exciting incidents.

- **Let autovacuum do its job — never disable it.** If a hot table churns, tune
  it *per-table* (`autovacuum_vacuum_scale_factor`, `..._cost_limit`), don't turn
  it off. Disabling autovacuum is how you meet XID wraparound.
- **ANALYZE after bulk loads.** The planner is only as good as its statistics.
  After a big import, `ANALYZE the_table;` before you trust query plans.
- **Watch bloat, reclaim deliberately.** Use the ioguix bloat-estimation queries
  (link in §6). For real reclamation without an `ACCESS EXCLUSIVE` lock, use
  `pg_repack`, **never** `VACUUM FULL` on a live table during business hours.
- **Reset `pg_stat_statements` on a cadence** (e.g. after each release) so the
  "top queries" reflect *now*, not all-time.
- **Schema migrations are dangerous DDL.** `ALTER TABLE` can take an `ACCESS
  EXCLUSIVE` lock and block the world. Always run migrations with a
  `lock_timeout` and retry, add indexes `CONCURRENTLY`, and split "add nullable
  column" from "backfill" from "add constraint."
- **Upgrades:** read the release notes for the breaking changes, test the
  migration on a restored copy, and never let yourself fall more than a couple
  of majors behind — catching up is worse than keeping up.

---

## 5. Security — the things I no longer think about

These are reflexes. Build them and they stop being decisions.

- **Apps never run as superuser.** Our app role (`commute`) owns its data and
  nothing more; `enableSuperuserAccess` stays off on the CNPG cluster. A
  compromised app should not be able to drop the cluster or read other DBs.
- **Least privilege, always.** Grant the minimum. Separate read-only roles for
  reporting/BI. No `GRANT ALL` reflexes.
- **Secrets never live in git.** CNPG owns the DB credentials (`<cluster>-app`
  secret); app/Django secrets come from Ansible/vault. Rotation is an operator
  action, not a code change. If a credential ever lands in a commit, treat it as
  compromised and rotate — git history is forever.
- **Audit the sensitive paths.** pgAudit (`write,ddl,role`) gives a tamper-
  evident trail of writes, schema changes, and privilege grants, shipped off-box
  to Loki/BetterStack so an attacker can't scrub it locally. Auditing only
  matters if the logs leave the machine.
- **Encrypt in transit.** CNPG does TLS between client and server and between
  primary and replicas by default. Don't undo it for convenience.
- **Minimize the attack surface.** The DB is `ClusterIP` only — no external
  exposure, no `LoadBalancer`. If you must reach it from your laptop, port-
  forward; don't punch a hole. Consider a `NetworkPolicy` so only the app
  namespace can reach 5432.
- **Bound the blast radius of runaway sessions:**
  `idle_in_transaction_session_timeout`, `statement_timeout` (sane app default),
  and a per-role `lock_timeout`. These have saved me from outages more than any
  firewall.
- **`search_path` hygiene.** A mutable `search_path` + `SECURITY DEFINER`
  functions is a classic privilege-escalation vector. Pin `search_path` on
  security-definer functions.
- **Backups you have *restored*.** A backup you've never restored is a rumor.
  > **Gap to close:** this cluster does not yet have continuous backup
  > configured. CNPG supports WAL archiving + base backups to object storage
  > (Barman plugin) with point-in-time recovery. Set it up, then schedule a
  > recurring **restore drill** — the only test that counts. Until then, a node
  > loss beyond replica redundancy means data loss.

---

## 6. The bookmarks — tools, sites, scripts I'm passing on

**Read these until they're instinct:**
- The official docs. Genuinely the best DB docs in the industry —
  https://www.postgresql.org/docs/current/
- **PostgreSQL Wiki** — *Don't Do This*, *Lock Monitoring*, *Monitoring*,
  *Slow Query Questions*: https://wiki.postgresql.org/
- **Use The Index, Luke!** (Markus Winand) — the best thing ever written on
  indexing and how queries actually use them: https://use-the-index-luke.com/

**EXPLAIN analysis (live by these during incidents):**
- explain.dalibo.com — visual plan analysis (paste `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`).
- explain.depesz.com — the classic; great for spotting the expensive node.
- **pgMustard** — opinionated plan tips; teaches you *why*.

**Dashboards / insight:**
- **pgHero** — instant "what's slow / unused indexes / bloat" UI; great triage.
- pganalyze — heavier, commercial, deep; worth it at scale.
- Our Grafana CNPG + pgAudit dashboards (see §2).

**Log analysis:**
- **pgBadger** — turns Postgres logs into a rich HTML report (slow queries,
  temp files, lock waits). Point it at a busy day's logs and learn a lot.

**Extensions to know cold:**
- `pg_stat_statements` (already on) — your single most valuable tuning tool.
- `auto_explain` — logs plans of slow queries automatically; turn it on when hunting.
- `pgstattuple` / `pg_buffercache` — real bloat and cache-content inspection.
- `pg_repack` — online bloat removal without the exclusive lock.

**Bloat estimation queries:**
- ioguix/pgsql-bloat-estimation — https://github.com/ioguix/pgsql-bloat-estimation
  (keep the table and index bloat SQL in your toolbox).

**CLI quality-of-life:**
- **pgcli** — autocompletion + syntax highlighting; once you switch you won't go back.
- **pgcenter** / pg_top — `top`-like live view of activity, locks, and stats.
- **pgbench** — built-in load generator; baseline before you tune, prove after.

**Cluster / operator:**
- CloudNativePG docs — https://cloudnative-pg.io/documentation/current/
  (read the sections on backup/recovery, monitoring, and failover before you need them).
- `kubectl cnpg` plugin — `status`, `psql`, `promote`, `restart`, `backup`.

**Keep learning:**
- *Postgres Weekly* newsletter and planet.postgresql.org — how I stayed current
  for fifteen years without trying.

---

## 7. Last words

Three things, if you forget everything else:

1. **Latency is a leading indicator; outages are a lagging one.** Watch the
   trends, not the thresholds.
2. **The dangerous transaction is the one that's still open.** Idle-in-
   transaction, long-running, uncommitted — that's where bloat, lock storms,
   and replication lag all start.
3. **Test your restores.** Everything else is recoverable if this one thing is true.

You'll be fine. The database wants to stay up — your job is mostly to not get in
its way, and to notice when something else is. Good luck.
