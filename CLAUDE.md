# CLAUDE.md — Homelab K8s Repo Guidelines

## Repo overview

GitOps homelab running k3s, managed with ArgoCD and Ansible. ArgoCD uses an
app-of-apps pattern to deploy Helm-based and raw-manifest apps. Ansible handles
cluster bootstrapping and secrets.

## Project structure

```
apps/
  argocd/
    app-of-apps.yml          # Root ArgoCD app — apply once via ansible, then self-managed
    apps/                    # One .yml per ArgoCD Application (Helm or raw manifests)
    disabled/                # Apps temporarily disabled (not picked up by app-of-apps)
  <app-name>/
    values.yml               # Helm values for the app
ansible/
  apps.yml                   # Provisions namespaces, secrets, and bootstraps ArgoCD
  site.yml                   # Cluster node setup
.github/
  workflows/
    validate.yml             # PR checks: helm template + kubeconform for every app
```

## Adding a new app

1. Create `apps/<name>/values.yml` with Helm chart configuration
2. Create `apps/argocd/apps/<name>.yml` using an existing app as a template
3. If the app needs secrets, add an Ansible task in `ansible/apps.yml` to create them
4. Open a PR — GHA validates the manifests, merge deploys via ArgoCD

## Workflow

- **All changes go through PRs** — never commit directly to `main`
- Branch off `main`, make changes, open a PR
- GHA runs `helm template` + `kubeconform` on every PR automatically
- ArgoCD auto-syncs from `main` (`HEAD`) after merge
- To test a change against the live cluster before merging: edit the specific
  ArgoCD child app in the UI and temporarily set `targetRevision` to your branch

## Templating layers — order matters

There are multiple systems that use `{{ }}` syntax at different stages:

| Layer | Runs when | Example |
|-------|-----------|---------|
| Ansible | Local, before anything hits the cluster | `{{ betterstack_logs_token }}` |
| Helm | At deploy time when ArgoCD syncs | `{{ .Release.Namespace }}` |
| App runtime (e.g. Vector) | Inside the pod, per log event | `{{ kubernetes.pod_namespace }}` |

When a later-layer `{{ }}` expression appears inside a Helm `values.yml` that
gets processed by `tpl`, escape it with Helm raw string syntax so Helm doesn't
evaluate it:

```yaml
# Wrong — Helm tries to call kubernetes() as a function:
namespace: "{{ kubernetes.pod_namespace }}"

# Correct — passes through to the app untouched:
namespace: '{{`{{ kubernetes.pod_namespace }}`}}'
```

## Secrets

Secrets are never stored in git. They are created by Ansible tasks in
`ansible/apps.yml` and must exist in the target namespace before ArgoCD syncs
the app that needs them.

## Disabling an app

Move its file from `apps/argocd/apps/` to `apps/argocd/disabled/`. The
app-of-apps will prune it from ArgoCD on next sync.

## Commit style

Follow conventional commits: `fix(scope):`, `feat(scope):`, `chore(scope):`,
`refactor(scope):`. Keep the subject line under 72 characters.

## Key apps

| App | Namespace | Purpose |
|-----|-----------|---------|
| prometheus-stack | monitoring | Metrics — Prometheus, Grafana, Alertmanager |
| loki | monitoring | Log storage |
| vector | vector | Log shipper — collects from all pods, ships to Loki and BetterStack |
| traefik | traefik | Ingress controller |
| cert-manager | cert-manager | TLS certificates |
| longhorn | longhorn-system | Distributed block storage |
| headlamp | headlamp | Kubernetes UI |
| betterstack-uptime | betterstack | Heartbeat monitors |
