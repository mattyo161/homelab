# Node Configuration — Declarative Labels and Taints

Node scheduling config (labels and taints) is declared in
`ansible/inventory/host_vars/<node>/main.yml` and applied
by the `node_config` Ansible role.

**This means:** to change which workloads run on which node,
edit a file and run a playbook. No `kubectl` commands to remember.
A full cluster wipe-and-rebuild produces identical scheduling.

## Current node roles

| Node | Hardware | Role | Labels | Taints |
|---|---|---|---|---|
| mou-mini1 | 2C / 15.4G | Control plane | `node-role=control-plane` | none |
| mou-mini2 | 4C / 3.7G  | Control plane | `node-role=control-plane` | none |
| mou-pc1   | 4C / 5.7G  | Control plane + GitLab app | `role=gitlab-app` | none |
| mou-mini4 | 4C / 15.5G | Worker + GitLab storage | `role=gitlab-storage` | none |
| mou-mini3 | 4C / 3.7G  | Worker + runner jobs | `role=runner` | none |
| mou-mini5 | 4C / 3.7G  | Worker + runner jobs | `role=runner` | none |
| mou-pi5   | 4C / 2.0G  | Worker (ARM64 only) | `role=arm64-only` | `arch=arm64:NoSchedule` (Longhorn replicas **excluded**) |

## How to change a node's role

Example: move GitLab storage tier from mini4 to a new node with more RAM.

```bash
# 1. Edit the host_vars files
vim ansible/inventory/host_vars/mou-mini4/main.yml
#    remove:  role: gitlab-storage
#    add:     role: worker

vim ansible/inventory/host_vars/mou-new-node/main.yml
#    add:     role: gitlab-storage

# 2. Apply to cluster
cd ansible
ansible-playbook -i inventory/hosts.yml node-config.yml

# 3. Update Helm values to match new label
vim apps/gitlab/values.yml
#    change affinity to point at new node's label

# 4. Commit everything
git add -A && git commit -m "move gitlab-storage to mou-new-node"
git push
# ArgoCD detects the values.yml change and resyncs GitLab
```

## How to add a new node

```bash
# 1. Add to inventory
vim ansible/inventory/hosts.yml
#    add under agent: hosts:
#      mou-new:
#        ansible_host: mou-new.oue.home

# 2. Create host_vars
cp ansible/inventory/host_vars/mou-mini3/main.yml \
   ansible/inventory/host_vars/mou-new/main.yml
vim ansible/inventory/host_vars/mou-new/main.yml
#    edit labels as appropriate

# 3. Run full provision (or just the phases needed)
ansible-playbook -i inventory/hosts.yml site.yml --limit mou-new
ansible-playbook -i inventory/hosts.yml node-config.yml --limit mou-new
```

## How to fix the control plane RAM imbalance

Currently mou-mini1 has 15.4G RAM but only 2 CPUs — it's the weakest
control plane node by CPU count. Options:

**Option A: Swap RAM sticks** between mou-mini1 and mou-mini3/5
- mini1 gets more CPUs (not possible without new hardware)
- mini3/5 get the 15.4G → more headroom for runner jobs

**Option B: Demote mou-mini1 to worker**
- Reduces control plane to 2 nodes (loses HA — not recommended)
- Or add a replacement control plane node first

**Option C: Keep current layout, just taint mini1**
- Prevents app workloads from landing on the 2-CPU node
- etcd still runs there but nothing else competes with it

To implement Option C (easiest):
```yaml
# ansible/inventory/host_vars/mou-mini1/main.yml
node_taints:
  - key: node-role.kubernetes.io/control-plane
    value: "true"
    effect: NoSchedule
```
Then run `ansible-playbook -i inventory/hosts.yml node-config.yml --limit mou-mini1`

## Full rebuild procedure

```bash
cd ansible

# 1. Provision OS-level config and k3s
ansible-playbook -i inventory/hosts.yml site.yml

# 2. Node labels/taints are applied automatically (Phase 5 of site.yml)
#    Or run standalone: ansible-playbook -i inventory/hosts.yml node-config.yml

# 3. ArgoCD syncs all apps from git automatically
#    Watch: kubectl get apps -n argocd -w

# 4. Re-create secrets that can't live in git:
#    - GitLab runner token (see apps/gitlab-runner/README)
#    - Ansible vault secrets
#    - Any manually created k8s secrets
```

## Why not use a Kubernetes operator for this?

Tools like Node Feature Discovery (NFD) or Cluster API can manage
node labels automatically based on hardware detection. For this homelab
the Ansible approach is simpler and more explicit — you can read
exactly what each node does from host_vars without knowing the operator's
labeling conventions. The tradeoff is manual updates when hardware changes,
which is acceptable at this scale.
