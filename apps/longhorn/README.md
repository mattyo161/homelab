# Longhorn

Longhorn is a distributed block storage system for Kubernetes. It creates replicated volumes across cluster nodes, providing persistent storage with snapshots, backups, and a web UI.

- **Docs:** https://longhorn.io/docs/
- **Helm chart:** https://charts.longhorn.io
- **GitHub:** https://github.com/longhorn/longhorn

## How it works in this cluster

Longhorn uses the `DATA1` partition mounted at `/mnt/data/DATA1` on each node (created by the `storage` Ansible role). Nodes without a `DATA1` mount fall back to `/var/lib/longhorn` on the root disk.

Each volume is replicated across 2 nodes by default (`defaultReplicaCount: 2`). Longhorn is the default StorageClass — the `local-path` default is removed by `apps.yml` after install.

Prerequisites: `open-iscsi` must be installed and `iscsid` running on all nodes. This is handled automatically by `ansible/apps.yml` before the Helm install.

## UI

URL: https://longhorn.oue.home

No login required by default — access is controlled at the network/ingress level. Consider adding basic auth via a Traefik middleware if the cluster is on a shared network.

## Managed by

Ansible (`ansible/apps.yml`, `--tags longhorn`). Not managed by ArgoCD — infrastructure layer.

## Validate it is running

```bash
# All pods should be Running
kubectl -n longhorn-system get pods

# Check Longhorn is the default StorageClass
kubectl get storageclass
# longhorn should show (default), local-path should not

# Check node storage status
kubectl -n longhorn-system get nodes.longhorn.io

# List all volumes
kubectl -n longhorn-system get volumes.longhorn.io
```

## Get current Helm config

```bash
helm get values longhorn -n longhorn-system
```

## Checking storage usage

```bash
# Check PersistentVolumeClaims across all namespaces
kubectl get pvc -A

# Check PersistentVolumes
kubectl get pv
```

## Troubleshooting

```bash
# Check Longhorn manager logs
kubectl -n longhorn-system logs -l app=longhorn-manager --tail=50

# Check if open-iscsi is running on nodes
ansible k3s_cluster -i inventory/hosts.yml -a "systemctl is-active iscsid" --become

# If a PVC is stuck in Pending
kubectl describe pvc <name> -n <namespace>

# Check volume replica health in the UI or via:
kubectl -n longhorn-system get replicas.longhorn.io
```
