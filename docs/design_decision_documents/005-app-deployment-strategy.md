# DDD 005 — Application deployment strategy: Helm via Ansible

| Field | Value |
|-------|-------|
| Status | Accepted |
| Date | 2026-04-07 |
| Deciders | Matt |
| Related | [app-deployment runbook](../runbooks/app-deployment.md), [DDD 002 — k3s-ansible collection](002-k3s-ansible-collection-vs-custom-roles.md) |

---

## Context

With the k3s cluster running reliably, the next need is to deploy and manage applications on top of it: an ingress controller, TLS certificates, monitoring, storage, and a dashboard. These applications need to be:

- **Repeatable** — re-running the same command should produce the same result
- **Version-controlled** — configuration lives in git, not in `kubectl apply` history
- **Consistent with existing tooling** — Ansible is already the infrastructure orchestrator; adding a separate tool with its own authentication and workflow has a cost
- **Upgradeable** — changing a chart version or values override should be a one-line diff

---

## Decision

Applications are deployed via **Helm**, driven by **Ansible** (`kubernetes.core.helm` module), with Helm values overrides stored as `apps/<app-name>/values.yml` in the repo. The entry point is `ansible/apps.yml`.

---

## Rationale

### Why Helm?

All four target applications (Traefik, cert-manager, kube-prometheus-stack, Headlamp, Longhorn, MetalLB) have maintained official or community Helm charts. Helm handles: chart versioning, templated manifests, upgrade lifecycle (pre/post hooks), CRD management, and dependency resolution between sub-charts. Writing and maintaining raw Kubernetes manifests for `kube-prometheus-stack` alone (which generates ~1000 resources) would be impractical.

### Why Ansible drives Helm rather than running Helm directly?

| Concern | Helm CLI directly | Ansible + kubernetes.core.helm |
|---------|------------------|-------------------------------|
| Dependency ordering | Manual, error-prone | Tasks run in sequence with wait conditions |
| Secrets management | Separate files or env vars | Integrates with Ansible Vault |
| Idempotency | `helm upgrade --install` is idempotent | Same — plus `check` mode support |
| Repo registration | Manual per machine | Automated in playbook |
| Node prerequisites (open-iscsi) | Completely separate concern | One playbook handles both node prep and Helm installs |
| Consistent UX | Different tool, different syntax | Same `ansible-playbook` command as infrastructure |

Running Helm through Ansible means a single `ansible-playbook apps.yml` command handles: installing prerequisites on nodes, registering Helm repos, installing/upgrading charts, and applying post-chart CRs — all in the correct order with proper wait conditions between steps.

### Why not GitOps (ArgoCD / Flux)?

GitOps pull-based systems continuously reconcile cluster state with git. This is the right model for production environments, but adds significant overhead for a homelab:

- ArgoCD or Flux are themselves in-cluster components that need to be bootstrapped and maintained
- They require separate CLIs (`argocd`, `flux`) with their own authentication flows
- App configuration becomes more distributed (App CRs, Kustomize overlays, separate repo structure)
- Debugging "why didn't this sync?" adds a layer of indirection vs. reading Ansible task output directly

The Ansible approach is "push on demand" — you run the playbook when you want to change something. This is a deliberate tradeoff: less automation in exchange for simpler mental model and fewer moving parts. A future DDD can revisit ArgoCD if the cluster grows significantly.

### Why not a separate `values.yml` per environment?

There is only one environment (homelab). A single `apps/<app>/values.yml` per app is sufficient. If a staging/prod split is ever needed, `apps/<app>/values-prod.yml` can be added and selected via an Ansible variable.

---

## Folder structure

```
homelab/
├── ansible/
│   ├── apps.yml              # entry point — runs Helm installs in order
│   └── ...
└── apps/
    ├── README.md             # DNS/TLS setup instructions
    ├── metallb/
    │   └── values.yml
    ├── cert-manager/
    │   ├── values.yml
    │   └── cluster-issuer.yml   # self-signed CA chain (applied post-install)
    ├── traefik/
    │   ├── values.yml
    │   └── README.md            # steps to disable built-in k3s Traefik first
    ├── longhorn/
    │   └── values.yml
    ├── prometheus-stack/
    │   └── values.yml
    └── headlamp/
        └── values.yml
```

---

## Install order and rationale

The dependency chain drives the install order in `apps.yml`:

1. **MetalLB** — must exist before any `LoadBalancer` service is created; Traefik depends on it
2. **cert-manager** — must exist and its webhook must be ready before any `Certificate` or `ClusterIssuer` resources are applied; Traefik and all app ingresses depend on it
3. **Traefik** — must exist before ingress hostnames for Longhorn, Prometheus, Grafana, and Headlamp work
4. **Longhorn** — must exist before any PVC with `storageClassName: longhorn` is created; Prometheus and Grafana depend on it
5. **kube-prometheus-stack** — depends on Longhorn (storage) and Traefik+cert-manager (ingress+TLS)
6. **Headlamp** — depends only on Traefik+cert-manager; could be installed earlier but kept last for clarity

---

## TLS approach

A **self-signed CA** managed by cert-manager is used for all ingress TLS. The CA is created once and stored as a Kubernetes Secret (`selfsigned-ca-secret` in the `cert-manager` namespace). All app certificates are issued by this CA via the `selfsigned-cluster-issuer` ClusterIssuer.

**Why not Let's Encrypt?** Let's Encrypt HTTP-01 requires ports 80/443 reachable from the internet. The homelab is behind a private network. DNS-01 requires a supported provider API. The self-signed CA approach works entirely offline, requires no external dependencies, and the CA cert only needs to be trusted in the browser once.

To trust the CA on macOS:

```bash
kubectl get secret -n cert-manager selfsigned-ca-secret \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > ~/homelab-ca.crt

sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ~/homelab-ca.crt
```

---

## Secrets management

The Grafana admin password is the only app-level secret. It is stored in `ansible/inventory/group_vars/k3s_cluster/secrets.yml` (vault-encrypted) as `vault_grafana_admin_password` and injected into the `helm` task via the `values:` override in `apps.yml`. It never appears in `apps/prometheus-stack/values.yml` (which is committed to git in plaintext).

---

## Consequences

### Positive

- Single command (`ansible-playbook apps.yml`) installs the entire app stack from scratch
- Values overrides are version-controlled and diffable
- Tags (`--tags prometheus`, `--tags traefik`) allow targeted re-runs
- Ansible Vault integration keeps secrets out of Helm values files
- `--check --diff` mode shows what would change before applying

### Negative / tradeoffs

- `helm` binary must be installed on the Ansible controller (in addition to `kubectl`)
- `kubernetes.core` collection must be installed (`ansible-galaxy collection install -r collections/requirements.yml`)
- Changes are push-based (run the playbook to apply); no automatic reconciliation if someone `kubectl apply`s something manually
- Large charts like `kube-prometheus-stack` have long first-install times (5-10 minutes)

---

## Alternatives considered

| Alternative | Why rejected |
|-------------|-------------|
| ArgoCD / Flux | Too much overhead for homelab; adds complexity without proportional value at this scale |
| Raw Kubernetes manifests | kube-prometheus-stack alone generates ~1000 resources; unmaintainable |
| Helm CLI only (no Ansible) | Loses dependency ordering, prereq installation, Vault integration, and consistent UX |
| Kustomize | Better for manifest patching than full chart management; Helm charts are the upstream format for all target apps |
