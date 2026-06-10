# Headlamp

Headlamp is a lightweight, extensible Kubernetes dashboard deployed via ArgoCD from `apps/argocd/apps/headlamp.yml`.

URL: https://headlamp.oue.home

## Authentication

Headlamp uses ServiceAccount token authentication. The Helm chart creates a `headlamp` ServiceAccount in the `headlamp` namespace and binds it to `cluster-admin` via the `headlamp-admin` ClusterRoleBinding.

### Generating a token

```bash
kubectl create token headlamp -n headlamp --duration=8760h
```

Copy the output and paste it into the Headlamp login screen. The token is a stateless JWT — it is not stored in the cluster and expires automatically after the specified duration.

Use `--duration=8760h` (1 year) as a reasonable homelab default. Avoid very long durations (e.g. 10 years) since stateless JWTs cannot be individually revoked — only invalidated by rotating the ServiceAccount (see below).

### Storing the token

Store the token in a password manager. There is no way to retrieve a previously generated token — if lost, generate a new one.

## Revoking tokens / rotating the ServiceAccount

Because `kubectl create token` produces stateless JWTs, there is no revocation list. The only way to invalidate all outstanding tokens is to delete and recreate the ServiceAccount. Kubernetes validates tokens against the SA's UID — a new SA gets a new UID, making all previously issued tokens invalid immediately.

```bash
# Delete the SA — all existing tokens are immediately invalid
kubectl delete serviceaccount headlamp -n headlamp
```

ArgoCD will detect the drift and recreate the SA on the next sync (within a few minutes), or trigger it manually:

```bash
argocd app sync headlamp
```

Then generate a new token:

```bash
kubectl create token headlamp -n headlamp --duration=8760h
```

## Adding additional users

For multi-user setups, create separate ServiceAccounts with narrower RBAC rather than sharing the cluster-admin token:

```bash
kubectl create serviceaccount <username> -n headlamp
kubectl create clusterrolebinding headlamp-<username> \
  --clusterrole=view \
  --serviceaccount=headlamp:<username>
kubectl create token <username> -n headlamp --duration=8760h
```

Replace `view` with `edit` or `cluster-admin` depending on the access level needed.

## Troubleshooting

```bash
# Check pods are running
kubectl -n headlamp get pods

# Check ingress is configured correctly
kubectl -n headlamp get ingress

# Check TLS certificate was issued
kubectl -n headlamp get certificate

# Check the ClusterRoleBinding is pointing to the right SA
kubectl get clusterrolebinding headlamp-admin -o jsonpath='{.subjects}'
```
