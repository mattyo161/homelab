# DDD 006 — ArgoCD for application management

| Field | Value |
|-------|-------|
| Status | Accepted |
| Date | 2026-04-07 |
| Deciders | Matt |
| Supersedes | DDD 005 (partially — infrastructure layer remains Ansible-managed) |
| Related | [app-deployment runbook](../runbooks/app-deployment.md), [DDD 005 — app deployment strategy](005-app-deployment-strategy.md) |

---

## Context

DDD 005 established Helm-via-Ansible as the deployment strategy for all applications. This worked, but as the number of managed apps grows, a purely push-based model has limitations:

- No visibility into drift — if someone `kubectl apply`s a change manually, there's no record and no automatic correction
- No self-healing — a deleted Deployment or misconfigured resource stays broken until the playbook is re-run
- No UI for deployment status — you must read Ansible output or run `kubectl` commands
- Upgrading one app requires re-running `apps.yml`, which touches everything

ArgoCD (a CNCF GitOps controller) continuously reconciles the cluster state with what's declared in git. Adding it gives continuous sync, drift detection, a visual dashboard, and per-app control — without replacing the existing Ansible infrastructure tooling.

---

## Decision

ArgoCD is added as a second tier in the deployment model:

**Tier 1 — Infrastructure (Ansible-managed):** MetalLB, cert-manager, Traefik, Longhorn. These must exist before ArgoCD can run or access the cluster. Ansible installs and upgrades them via `ansible/apps.yml`.

**Tier 2 — Applications (ArgoCD-managed):** Everything else. ArgoCD is bootstrapped by Ansible once, then manages itself and all other apps by watching `apps/argocd/apps/` in this git repo.

The **App of Apps** pattern is used: a single root `Application` resource (`apps/argocd/app-of-apps.yml`) points ArgoCD at the `apps/argocd/apps/` directory. Every file in that directory is an ArgoCD `Application` that ArgoCD syncs independently.

---

## Rationale

### Why ArgoCD and not Flux?

Both are CNCF-graduated GitOps tools. The key differences relevant to this homelab:

| Concern | ArgoCD | Flux |
|---------|--------|------|
| UI | Built-in web dashboard | No built-in UI (need Weave GitOps or similar) |
| App of Apps | Native Application CRD | Kustomization + HelmRelease CRDs |
| CLI | `argocd` CLI | `flux` CLI |
| Config style | Application YAML per app | HelmRelease + GitRepository per app |
| Helm values from separate repo | Native multi-source support | Supported via HelmRelease |

ArgoCD's web UI is a significant advantage for a homelab — being able to see sync status, resource health, and diffs visually reduces the need to run `kubectl` for routine checks.

### Why not replace the infrastructure layer with ArgoCD too?

A bootstrapping problem exists: ArgoCD needs MetalLB (for its LoadBalancer ingress), cert-manager (for its TLS cert), and Traefik (for routing to its dashboard) to be running before it can be useful. These components have no circular dependency on ArgoCD, so keeping them Ansible-managed is clean and simple. Ansible is already the tool for infrastructure provisioning.

### Why App of Apps instead of individual Applications applied by Ansible?

If Ansible applied each ArgoCD `Application` directly, adding a new app would require both a git commit (for the values) and a playbook run (to apply the Application manifest). The App of Apps pattern means Ansible only needs to apply **one** manifest — the root Application — after which ArgoCD discovers and manages everything in `apps/argocd/apps/` automatically. Adding a new app is just: create the files, push to git.

### Why keep Helm values files in `apps/<app>/values.yml` rather than inline in the Application manifest?

Keeping values in separate files makes them readable, diffable, and reusable. The ArgoCD Application manifest uses the multi-source feature (`sources:` with a `ref: values` source) to load values from this repo alongside the Helm chart. This means the chart always comes from its upstream Helm repo (with a pinned version) while the values come from git.

---

## Architecture

```
ansible/apps.yml
  └── Installs (once, idempotent):
        MetalLB → cert-manager → Traefik → Longhorn → ArgoCD
                                                           │
                                            applies app-of-apps.yml
                                                           │
                                                     ArgoCD watches
                                               apps/argocd/apps/*.yml
                                                    │         │
                                          prometheus-stack  headlamp
                                          (+ future apps)
```

---

## File structure

```
apps/
├── argocd/
│   ├── values.yml           # ArgoCD Helm values (ingress, no dex, insecure mode)
│   ├── app-of-apps.yml      # Root Application — points ArgoCD at apps/argocd/apps/
│   └── apps/
│       ├── prometheus-stack.yml    # ArgoCD Application for kube-prometheus-stack
│       └── headlamp.yml            # ArgoCD Application for Headlamp
├── cert-manager/            # Ansible-managed (infra layer)
├── traefik/                 # Ansible-managed (infra layer)
├── metallb/                 # Ansible-managed (infra layer)
├── longhorn/                # Ansible-managed (infra layer)
├── prometheus-stack/        # values.yml consumed by ArgoCD Application
└── headlamp/                # values.yml consumed by ArgoCD Application
```

---

## Sync policy

All ArgoCD-managed Applications use:

```yaml
syncPolicy:
  automated:
    prune: true      # remove resources deleted from git
    selfHeal: true   # revert manual changes made outside git
```

This means: push to git → ArgoCD detects the change within ~3 minutes and syncs automatically. No manual `argocd app sync` needed for routine updates.

---

## Secrets management

ArgoCD itself does not store application secrets. Grafana's admin password continues to flow through Ansible Vault → `apps.yml` `values:` override → Helm. For future apps that need secrets, options include:

- **External Secrets Operator** (pulls from a secrets backend like Vault or AWS Secrets Manager) — recommended if the number of secrets grows
- **Sealed Secrets** (encrypts secrets in git) — simpler but requires the `kubeseal` CLI

This is deferred to a future DDD.

---

## Consequences

### Positive

- Continuous sync — git is always the source of truth; drift is automatically corrected
- Visual dashboard at `https://argocd.oue.home` shows all app health and sync status
- Adding a new app is a git commit only (no playbook run needed after bootstrap)
- Per-app sync control — can pause, rollback, or force-sync individual apps without touching others
- ArgoCD manages its own updates (chart version bump in values.yml → auto-sync → ArgoCD upgrades itself)

### Negative / tradeoffs

- ArgoCD is an in-cluster component that must be healthy for app management to work; if it goes down, apps keep running but won't receive updates
- The repo URL in `app-of-apps.yml` must be updated to the real GitHub URL before bootstrapping
- Multi-source ArgoCD Applications (values from git + chart from Helm repo) require ArgoCD 2.6+
- `selfHeal: true` means any manual `kubectl` change will be reverted — intentional, but requires awareness

---

## Alternatives considered

| Alternative | Why rejected |
|-------------|-------------|
| Flux | No built-in UI; similar complexity to ArgoCD without the dashboard benefit |
| Ansible-only (DDD 005) | No drift detection, no self-healing, no visual status; adequate for initial setup but limited as app count grows |
| ArgoCD manages everything (incl. infra) | Bootstrapping chicken-and-egg problem: ArgoCD needs MetalLB/cert-manager/Traefik to be accessible |
| ArgoCD with separate config repo | Additional repo to manage; no benefit at homelab scale with a single operator |
