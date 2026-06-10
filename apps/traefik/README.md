# Traefik

Traefik is a cloud-native reverse proxy and ingress controller. It automatically discovers services and routes traffic based on Kubernetes Ingress and IngressRoute resources.

- **Docs:** https://doc.traefik.io/traefik/
- **Helm chart:** https://traefik.github.io/charts
- **GitHub:** https://github.com/traefik/traefik

## How it works in this cluster

Traefik replaces the k3s built-in Traefik and is installed via Helm with a MetalLB-assigned LoadBalancer IP (`192.168.5.200`). All HTTP traffic on port 80 is redirected to HTTPS on port 443.

All app ingress resources use `ingressClassName: traefik` and the annotation `traefik.ingress.kubernetes.io/router.entrypoints: websecure` to route through the HTTPS entrypoint. TLS certificates are issued by cert-manager and referenced via `secretName` in the Ingress TLS block.

## Disabling the built-in k3s Traefik

The built-in k3s Traefik must be disabled before deploying this Helm-managed version. This is handled via `server_config_yaml` in `ansible/inventory/group_vars/k3s_cluster/main.yml`:

```yaml
server_config_yaml: |
  disable:
    - traefik
```

Apply with `ansible-playbook -i inventory/hosts.yml k3s.orchestration.site --limit server`, then delete the existing HelmChart releases if they still exist:

```bash
helm uninstall traefik -n kube-system
helm uninstall traefik-crd -n kube-system
```

## Managed by

Ansible (`ansible/apps.yml`, `--tags traefik`). Not managed by ArgoCD — infrastructure layer.

## Validate it is running

```bash
# Traefik pod should be Running in the traefik namespace
kubectl -n traefik get pods

# Verify MetalLB assigned the correct IP
kubectl -n traefik get svc traefik
# EXTERNAL-IP should be 192.168.5.200

# List all ingress routes
kubectl get ingressroute -A
kubectl get ingress -A

# Test HTTP->HTTPS redirect
curl -i http://192.168.5.200/
# Should return 301 to https://
```

## Get current Helm config

```bash
helm get values traefik -n traefik
```

## Troubleshooting

```bash
# Check Traefik logs
kubectl -n traefik logs -l app.kubernetes.io/name=traefik --tail=50

# Check access logs (enabled in values.yml)
kubectl -n traefik logs -l app.kubernetes.io/name=traefik --tail=100 | grep -v "healthcheck"

# Describe the service to check MetalLB assignment
kubectl -n traefik describe svc traefik

# If getting 404 for a known host, check the ingress is present and has an address
kubectl get ingress -A
kubectl describe ingress <name> -n <namespace>
```
