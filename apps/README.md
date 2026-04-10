# apps/

Application configuration for the k3s homelab cluster. Split into two layers:

## Layer 1: Infrastructure (Ansible-managed)

These components must exist before ArgoCD can run. `ansible/apps.yml` installs and upgrades them directly via Helm.

| App | Namespace | Purpose |
|-----|-----------|---------|
| MetalLB | metallb-system | LoadBalancer IP assignment (pool: 192.168.5.200-210) |
| cert-manager | cert-manager | TLS certificate issuance (self-signed CA) |
| Traefik | traefik | Ingress controller, HTTP→HTTPS redirect |
| Longhorn | longhorn-system | Distributed block storage |

## Layer 2: Applications (ArgoCD-managed)

Everything else is declared as ArgoCD `Application` resources in `apps/argocd/apps/`. ArgoCD watches this directory in git and syncs changes automatically.

| App | Namespace | ArgoCD Application file |
|-----|-----------|------------------------|
| ArgoCD | argocd | (bootstrapped by Ansible, then self-managed) |
| kube-prometheus-stack | monitoring | `apps/argocd/apps/prometheus-stack.yml` |
| Headlamp | headlamp | `apps/argocd/apps/headlamp.yml` |

### Adding a new app

1. Create `apps/<app-name>/values.yml` with Helm values overrides
2. Create `apps/argocd/apps/<app-name>.yml` with the ArgoCD Application manifest
3. Push to git — ArgoCD detects the new Application and syncs it automatically

## Bootstrapping (first time)

```bash
# 1. Disable built-in k3s Traefik first (see apps/traefik/README.md)
# 2. Install infrastructure + ArgoCD
ansible-playbook -i inventory/hosts.yml apps.yml

# 3. Add DNS records (see below)
# 4. Trust the CA cert in your browser (see below)
```

## DNS setup (Pi-hole)

After `apps.yml` completes, add to Pi-hole:

```
k3s.oue.home        A      192.168.5.200     # MetalLB IP assigned to Traefik
argocd.oue.home     CNAME  k3s.oue.home
grafana.oue.home    CNAME  k3s.oue.home
prometheus.oue.home CNAME  k3s.oue.home
headlamp.oue.home   CNAME  k3s.oue.home
traefik.oue.home    CNAME  k3s.oue.home
longhorn.oue.home   CNAME  k3s.oue.home
```

Verify the Traefik IP:

```bash
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## TLS — trust the self-signed CA

```bash
kubectl get secret -n cert-manager selfsigned-ca-secret \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > ~/homelab-ca.crt

# macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ~/homelab-ca.crt
```

## App URLs

| App | URL | Credentials |
|-----|-----|-------------|
| ArgoCD | https://argocd.oue.home | admin / printed by apps.yml |
| Grafana | https://grafana.oue.home | admin / vault_grafana_admin_password |
| Prometheus | https://prometheus.oue.home | none |
| Traefik | https://traefik.oue.home/dashboard/ | none |
| Longhorn | https://longhorn.oue.home | none |
| Headlamp | https://headlamp.oue.home | token printed by ArgoCD sync |
