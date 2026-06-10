# Longhorn

Longhorn is a distributed block storage system for Kubernetes. It creates replicated volumes across cluster nodes, providing persistent storage with snapshots, backups, and a web UI.

- **Docs:** https://longhorn.io/docs/
- **Helm chart:** https://charts.longhorn.io
- **GitHub:** https://github.com/longhorn/longhorn

## How it works in this cluster

Longhorn uses the `DATA1` partition mounted at `/mnt/data/DATA1` on each node (created by the `storage` Ansible role). Nodes without a `DATA1` mount fall back to `/var/lib/longhorn` on the root disk.

Each volume is replicated across 2 nodes by default (`defaultReplicaCount: 2`). Longhorn is the default StorageClass — the `local-path` default is removed by `apps.yml` after install.

Prerequisites: `open-iscsi` must be installed and `iscsid` running on all nodes. This is handled automatically by `ansible/apps.yml` before the Helm install.

## Storage nodes (replica placement)

Replicas are scheduled only on **amd64 worker nodes with healthy DATA1 disks**:

| Node | Longhorn replicas |
|------|-------------------|
| mou-mini3 | ✓ allowed |
| mou-mini4 | ✓ allowed (GitLab storage tier) |
| mou-mini5 | ✓ allowed |
| mou-pc1 | ✓ allowed |
| mou-pi5 | **✗ excluded** — ARM64 only, `arch=arm64:NoSchedule` |
| mou-mini1 | **✗ excluded** — cordoned control plane |

Exclusion is enforced by `longhorn_excluded_nodes` in `ansible/inventory/group_vars/k3s_cluster/main.yml` and applied on every `ansible/apps.yml --tags longhorn` run.

**Important:** disabling the node is not enough — each disk on the node must also have `allowScheduling: false`. Otherwise Longhorn can still place replicas there (this caused repeat issues on mou-pi5).

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

# Node scheduling — pi5 and mini1 should show allowScheduling=false
kubectl -n longhorn-system get nodes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,SCHEDULABLE:.spec.allowScheduling'

# List volumes and robustness
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness'
```

## Fixing degraded volumes

Degraded volumes usually mean a replica is **stopped**, **error**, or stuck on an **excluded node** (mou-pi5). GitLab PVCs are the most affected in this cluster.

### 1. Check volume health

```bash
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,ROBUSTNESS:.status.robustness,NODE:.status.currentNodeID'

kubectl -n longhorn-system get replicas.longhorn.io \
  -o custom-columns='VOLUME:.spec.volumeName,NODE:.spec.nodeID,STATE:.status.currentState' \
  | sort
```

Or open https://longhorn.oue.home → **Volume** → look for `Degraded` / `Faulted`.

### 2. Ensure mou-pi5 cannot receive replicas

```bash
# Node + disk must both be disabled; eviction moves replicas once a healthy copy exists elsewhere
kubectl -n longhorn-system patch nodes.longhorn.io mou-pi5 --type=merge -p '{
  "spec": {
    "allowScheduling": false,
    "evictionRequested": true,
    "disks": {
      "default-disk-d13531a75ae1003e": {
        "allowScheduling": false,
        "evictionRequested": true
      }
    }
  }
}'
```

Re-apply via Ansible:

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/apps.yml --tags longhorn
```

### 3. Wait for rebuild (do not delete the only running replica)

Longhorn refuses to delete a replica if it is the **only healthy copy** of a volume. You must first get a second healthy replica on an allowed node (mini3/4/5 or pc1).

Watch rebuild progress in the Longhorn UI or:

```bash
kubectl -n longhorn-system get replicas.longhorn.io -w
```

### 4. After a healthy replica exists on an allowed node

Once eviction completes (no replicas left on mou-pi5):

```bash
kubectl -n longhorn-system get replicas.longhorn.io --field-selector spec.nodeID=mou-pi5
# should return nothing
```

Volumes should return to `healthy` once each has 2 running replicas on allowed nodes.

### 5. Stuck replicas

In the Longhorn UI: **Volume** → select volume → **Replicas** → delete **stopped/error** replicas on bad nodes (not the only running one). Longhorn will recreate them on schedulable nodes.

## Get current Helm config

```bash
helm get values longhorn -n longhorn-system
```

## Checking storage usage

```bash
kubectl get pvc -A
kubectl get pv
```

## Troubleshooting

```bash
kubectl -n longhorn-system logs -l app=longhorn-manager --tail=50
ansible k3s_cluster -i inventory/hosts.yml -a "systemctl is-active iscsid" --become
kubectl describe pvc <name> -n <namespace>
kubectl -n longhorn-system get replicas.longhorn.io
```

Query Longhorn logs in Grafana (Loki):

```logql
{namespace="longhorn-system"} |~ "(?i)warn|error|fail|degraded"
```
