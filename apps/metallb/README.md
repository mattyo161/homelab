# MetalLB

MetalLB is a bare-metal load balancer for Kubernetes. It watches for Services of type `LoadBalancer` and assigns IPs from a configured address pool, enabling external access to cluster services without a cloud provider.

- **Docs:** https://metallb.io/
- **Helm chart:** https://metallb.github.io/metallb
- **GitHub:** https://github.com/metallb/metallb

## How it works in this cluster

MetalLB operates in L2 (ARP) mode. It announces the assigned IP (`192.168.5.200`) from whichever node is currently the leader for that service. All nodes run the `metallb-speaker` DaemonSet to participate in leader election and ARP announcements.

The IP pool (`192.168.5.200–192.168.5.210`) and L2Advertisement are created as Kubernetes CRs in `ansible/apps.yml` after the Helm chart installs the CRDs.

## Managed by

Ansible (`ansible/apps.yml`, `--tags metallb`). Not managed by ArgoCD — infrastructure layer.

## Validate it is running

```bash
# All speaker pods should be 4/4 Running (one per node)
kubectl -n metallb-system get pods

# Check the IP pool configuration
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# Verify Traefik got the expected IP
kubectl -n traefik get svc traefik
# EXTERNAL-IP should be 192.168.5.200
```

## Get current Helm config

```bash
helm get values metallb -n metallb-system
```

## Troubleshooting

```bash
# Check speaker logs on a specific node
kubectl -n metallb-system logs -l component=speaker --tail=50

# Check controller logs
kubectl -n metallb-system logs -l component=controller --tail=50

# If a service is stuck Pending with no EXTERNAL-IP, describe it
kubectl describe svc <service-name> -n <namespace>
```
