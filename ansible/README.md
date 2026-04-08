# Homelab k3s Ansible Playbooks

Provisions a k3s homelab cluster with control-plane (`server`) and worker (`agent`) groups, distributed across mixed hardware. Configs change over time; these docs may not always match the live layout.

**Repeatable setup and decisions:** see [docs/SETUP.md](../docs/SETUP.md) (paved path), [docs/NOTES.md](../docs/NOTES.md) (running notes), and [docs/design_decision_documents/](../docs/design_decision_documents/) (ADRs).

## Prerequisites

- **[mise](https://mise.jdx.dev/)** on your control machine — manages Python, Helm, and kubectl versions and creates the project `.venv/` (see [docs/SETUP.md](../docs/SETUP.md) for the full bootstrap sequence)
- SSH key-based access to all nodes
- **Passwordless sudo** (or equivalent) for the Ansible user on targets — see `bootstrap-sudo.yaml` / `bootstrap-user-ansible.yaml`
- Raspberry Pi OS Lite 64-bit, Ubuntu Server, or other OSes supported by [k3s-io/k3s-ansible](https://github.com/k3s-io/k3s-ansible)
- Each node has `~/.ssh/authorized_keys` updated for your key (or the dedicated `ansible` user after bootstrap)

## k3s: Galaxy collection

Cluster install uses the official **`k3s.orchestration`** collection ([k3s-io/k3s-ansible](https://github.com/k3s-io/k3s-ansible)), not the legacy `roles/k3s*`.

### Install collections and Python dependencies

The recommended approach uses [mise](https://mise.jdx.dev/) from the **repo root**:

```bash
mise install     # installs pinned python, helm, kubectl
mise run deps    # installs ansible + Python deps into .venv/, then Ansible collections
```

`mise` creates a project-local `.venv/` and activates it automatically (requires `mise activate` in your shell profile). After that, `ansible-playbook` and all other tools resolve to the correct versions without manual PATH management.

To run steps individually from the `ansible/` directory:

```bash
pip install -r requirements.txt
ansible-galaxy collection install -r collections/requirements.yml
```

`requirements.txt` installs `ansible` itself along with the Python `kubernetes` client and supporting libraries — all in the same `.venv/` interpreter that `ansible-playbook` uses at runtime. `collections/requirements.yml` pulls `k3s.orchestration`, `kubernetes.core`, `community.general`, and `ansible.posix`.

### Cluster token and secrets

1. Copy the example secrets file:

   ```bash
   cp group_vars/k3s_cluster/secrets.yml.example group_vars/k3s_cluster/secrets.yml
   ```

2. Set `token` to a long random string (e.g. `openssl rand -base64 64`).

3. Encrypt with Ansible Vault (recommended):

   ```bash
   ansible-vault encrypt group_vars/k3s_cluster/secrets.yml
   ```

4. Run playbooks with `--ask-vault-pass` or a **local** `vault_password_file` in `ansible.cfg` (do not commit the password file).

`group_vars/k3s_cluster/main.yml` holds non-secret settings (`k3s_version`, `api_endpoint`, `cluster_context`). With **three** nodes in `server`, the collection installs **embedded etcd HA**; for a single stable API address in front of all servers, set `api_endpoint` to your DNS/VIP instead of the default first-host expression.

## Project structure

```
ansible/
├── ansible.cfg
├── site.yml
├── collections/
│   └── requirements.yml       # k3s.orchestration + pin
├── inventory/
│   └── hosts.yml              # k3s_cluster → server, agent
├── group_vars/
│   └── k3s_cluster/
│       ├── main.yml           # k3s_version, api_endpoint, cluster_context
│       └── secrets.yml.example
├── host_vars/                 # per-host vars (e.g. rpi-connect)
└── roles/
    ├── common/
    ├── storage/
    ├── rpi_connect/
    └── k3s, k3s_server, k3s_agent/   # legacy (unused; collection replaces)
```

## Setup

### 1. Install Galaxy collections and secrets

See [k3s: Galaxy collection](#k3s-galaxy-collection) above.

### 2. Optional: rpi-connect keys

Edit `host_vars/<hostname>.yml` with rpi-connect keys from https://connect.raspberrypi.com/settings when using the `rpi_connect` role.

### 3. Verify SSH

```bash
cd ansible
ansible all -i inventory/hosts.yml -m ping
```

### 4. Run the full playbook

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

If `secrets.yml` is vault-encrypted, add `--ask-vault-pass` (or configure `vault_password_file`).

## Run individual phases

```bash
# Common role only
ansible-playbook -i inventory/hosts.yml site.yml --tags common

# Storage / rpi_connect (when those plays are uncommented in site.yml)
ansible-playbook -i inventory/hosts.yml site.yml --tags storage
ansible-playbook -i inventory/hosts.yml site.yml --tags rpi_connect

# k3s only (collection playbook; same inventory and group_vars apply)
ansible-playbook -i inventory/hosts.yml k3s.orchestration.site --ask-vault-pass

# Refresh kubeconfig on controller after install (per upstream README)
ansible-playbook -i inventory/hosts.yml k3s.orchestration.site --tags kubeconfig --ask-vault-pass

# Upgrade k3s after bumping k3s_version in group_vars/k3s_cluster/main.yml
ansible-playbook -i inventory/hosts.yml k3s.orchestration.upgrade --ask-vault-pass

# Dry run
ansible-playbook -i inventory/hosts.yml site.yml --check

# Limit to one host
ansible-playbook -i inventory/hosts.yml site.yml --limit mou-pi5
```

The k3s collection plays use **upstream** tags (not `common`). With `site.yml`, `--tags common` typically runs **only** the common play and **skips** the imported k3s plays. Run **`k3s.orchestration.site`** directly when you want k3s only.

## After install

### kubectl on the Ansible controller

The collection merges kubeconfig into **`~/.kube/config`** with context **`k3s-ansible`** (override with `cluster_context` in `group_vars/k3s_cluster/main.yml`).

```bash
kubectl config use-context k3s-ansible
kubectl get nodes
```

Ensure the API URL in that context is reachable from your machine (same network or correct `api_endpoint` / DNS).

### Verify from a node

If `kubectl` is configured on a server node:

```bash
sudo kubectl get nodes
```

## Adding a new node

1. Install OS and SSH access.
2. Add the host under `server` or `agent` in `inventory/hosts.yml`.
3. Add `host_vars/<hostname>.yml` if needed (e.g. rpi-connect).
4. Run:

   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml --limit <hostname> --ask-vault-pass
   ```

## Notes

- rpi-connect auth keys are **one use only** — use a fresh key per node where applicable.
- The storage role does **not** reformat drives if partitions already exist.
- [K3s requirements](https://docs.k3s.io/installation/requirements): swap, firewall, and OS prep matter for a clean install.
