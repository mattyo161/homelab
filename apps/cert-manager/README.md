# cert-manager

cert-manager automates the management and issuance of TLS certificates in Kubernetes. It watches `Certificate` and `Ingress` resources and issues certificates via configured `Issuer` or `ClusterIssuer` resources.

- **Docs:** https://cert-manager.io/docs/
- **Helm chart:** https://charts.jetstack.io
- **GitHub:** https://github.com/cert-manager/cert-manager

## How it works in this cluster

A self-signed `ClusterIssuer` chain is used for homelab TLS:

1. `selfsigned-issuer` — bootstraps a root CA certificate
2. `homelab-ca` — the root CA Certificate signed by `selfsigned-issuer`
3. `selfsigned-cluster-issuer` — the `ClusterIssuer` used by all apps to issue leaf certificates

All app ingress resources reference `selfsigned-cluster-issuer` via the annotation `cert-manager.io/cluster-issuer: selfsigned-cluster-issuer`. The resulting certificates are stored as Secrets in each app's namespace.

Because the CA is self-signed, browsers will show a security warning unless you import the CA certificate into your system/browser trust store (see Trusting the CA below).

## Managed by

Ansible (`ansible/apps.yml`, `--tags cert-manager`). Not managed by ArgoCD — infrastructure layer.

## Validate it is running

```bash
# All pods should be Running
kubectl -n cert-manager get pods

# Check the ClusterIssuers are Ready
kubectl get clusterissuer

# Check certificates across all namespaces
kubectl get certificate -A

# Check a specific certificate's details
kubectl describe certificate <name> -n <namespace>
```

## Get current Helm config

```bash
helm get values cert-manager -n cert-manager
```

## Trusting the CA

To avoid browser warnings, export the CA certificate and add it to your system trust store:

```bash
# Export the CA cert
kubectl get secret homelab-ca -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.crt

# macOS — add to system keychain and trust
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain homelab-ca.crt
```

## Troubleshooting

```bash
# Check certificate request status
kubectl get certificaterequest -A

# Check ACME challenges (not used here, but useful reference)
kubectl get challenge -A

# Check cert-manager controller logs
kubectl -n cert-manager logs -l app=cert-manager --tail=50

# If a certificate is stuck, describe it for events
kubectl describe certificate <name> -n <namespace>
```
