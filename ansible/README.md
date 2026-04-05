# Homelab k3s Ansible Playbooks

Provisions a k3s homelab cluster with 3 control-plane nodes and 3 workder nodes, distributed across a mix of hardware. Configs will certainly change overtime as such these docs may not always be up to date.

## Prerequisites

- Ansible installed on your MacBook
- SSH key-based access to both Pis
- Both Pis running Raspberry Pi OS Lite 64-bit
- USB drives attached to both nodes
- Mac Minis with Ubuntu 24.04 Server installed
- PC with Linux installed
- Each instance has `~/.ssh/authorized_keys` updated with laptop ssh key

## Project Structure

```
ansible/
├── ansible.cfg               # Ansible config
├── site.yml                  # Main playbook
├── inventory/
│   └── hosts.yml             # Node inventory
├── group_vars/
│   └── all.yml               # Variables for all nodes
├── host_vars/
│   ├── mou-pi5.yml           # Pi 5 specific vars (rpi-connect key)
│   └── mou-pi4.yml           # Pi 4 specific vars (rpi-connect key)
└── roles/
    ├── common/               # cgroups, swap, packages
    ├── storage/              # USB partitioning + mounting
    ├── rpi_connect/          # rpi-connect-lite setup
    ├── k3s/                  # k3s common configuration
    ├── k3s_server/           # k3s control plane
    └── k3s_agent/            # k3s worker node
```

## Setup

### 1. Update auth keys
Edit `host_vars/mou-pi5.yml` and `host_vars/mou-pi4.yml` with your rpi-connect auth keys from https://connect.raspberrypi.com/settings

### 2. Verify SSH access
```bash
ansible all -i inventory/hosts.yml -m ping
```

### 3. Run the full playbook
```bash
ansible-playbook site.yml
```

## Run Individual Phases

```bash
# Common setup only (cgroups, swap, packages)
ansible-playbook site.yml --tags common

# Storage only (partition + mount USB drives)
ansible-playbook site.yml --tags storage

# rpi-connect only
ansible-playbook site.yml --tags rpi_connect

# k3s install only (server + agent)
ansible-playbook site.yml --tags k3s

# Dry run (no changes made)
ansible-playbook site.yml --check

# Single host only
ansible-playbook site.yml --limit mou-pi5
```

## After Install

### Verify cluster
```bash
# On mou-pi5
kubectl get nodes

# Expected output:
# NAME       STATUS   ROLES                  AGE   VERSION
# mou-pi5    Ready    control-plane,master   Xm    v1.29.x
# mou-pi4    Ready    <none>                 Xm    v1.29.x
```

### Use kubectl from MacBook
The playbook fetches the kubeconfig to `~/.kube/config-mou-pi5`.
Update the server IP and merge with your local kubeconfig:

```bash
# Update server address in fetched config
sed -i 's/127.0.0.1/<pi5-ip>/g' ~/.kube/config-mou-pi5

# Set as active config
export KUBECONFIG=~/.kube/config-mou-pi5

# Verify
kubectl get nodes
```

## Adding a New Node

1. Flash Raspberry Pi OS Lite 64-bit
2. Add node to `inventory/hosts.yml` under `workers`
3. Add `host_vars/<hostname>.yml` with rpi-connect key
4. Run:
```bash
ansible-playbook site.yml --limit <new-hostname>
```

## Notes

- rpi-connect auth keys are **one use only** — get a fresh key per node from connect.raspberrypi.com
- The storage role will **not** reformat drives if partitions already exist
- k3s server must complete before agents can join — site.yml handles this ordering automatically
