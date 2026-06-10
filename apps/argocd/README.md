# ArgoCD

ArgoCD is a declarative GitOps continuous delivery tool for Kubernetes. It watches git repositories and automatically syncs the cluster state to match what is defined in git.

- **Docs:** https://argo-cd.readthedocs.io/
- **Helm chart:** https://argoproj.github.io/argo-helm
- **GitHub:** https://github.com/argoproj/argo-cd

## How it works in this cluster

ArgoCD is bootstrapped by Ansible (`ansible/apps.yml`, `--tags argocd`), then manages itself and all other apps via the "App of Apps" pattern:

- `apps/argocd/app-of-apps.yml` — the root Application, applied once by Ansible, points ArgoCD at `apps/argocd/apps/` in this repo
- `apps/argocd/apps/*.yml` — one Application manifest per app; ArgoCD discovers and syncs these automatically
- To add a new app: create `apps/argocd/apps/<name>.yml` and push to git

## UI

URL: https://argocd.oue.home

## Login

### First time (initial admin password)

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Login with username `admin` and the password above. Change the password after first login via **User Info → Update Password** in the UI.

### CLI login

```bash
argocd login argocd.oue.home --username admin --password <password> --insecure
```

### After changing the password

The `argocd-initial-admin-secret` can be deleted once you have set a new password — it is no longer needed:

```bash
kubectl -n argocd delete secret argocd-initial-admin-secret
```

## Day-to-day operations

```bash
# List all apps and their sync status
argocd app list

# Sync a specific app manually
argocd app sync <app-name>

# Sync all apps
argocd app sync --all

# Check app health and sync status
argocd app get <app-name>

# Force a hard refresh (re-fetches from git)
argocd app get <app-name> --hard-refresh
```

## Adding a new app

1. Create `apps/argocd/apps/<name>.yml` with an ArgoCD `Application` manifest
2. Create `apps/<name>/values.yml` with Helm values
3. Push to the `ansible-k8s-core` branch
4. ArgoCD will detect the new manifest on next sync (or click SYNC on `app-of-apps` in the UI)

## Managed by

Ansible bootstraps it once (`ansible/apps.yml`, `--tags argocd`). After that ArgoCD manages itself via `selfHeal: true`.

## Validate it is running

```bash
# All pods should be Running
kubectl -n argocd get pods

# Check all apps are Healthy and Synced
argocd app list

# Check ingress
kubectl -n argocd get ingress

# Check TLS certificate
kubectl -n argocd get certificate
```

## Get current Helm config

```bash
helm get values argocd -n argocd
```

## Troubleshooting

```bash
# Check ArgoCD server logs
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-server --tail=50

# Check repo server logs (git fetch issues show up here)
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-repo-server --tail=50

# Check application controller logs (sync errors show up here)
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=50

# If an app is OutOfSync but won't sync
argocd app sync <app-name> --force

# If an app is in an error state, describe it
argocd app get <app-name>
```
