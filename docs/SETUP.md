# Homelab setup — paved path

Chronological steps to reproduce this environment from a cold start. Adjust hostnames, users, and domains to match your network.

## 0. What you are building

- **Ansible** manages a **`k3s_cluster`** inventory group with:
  - **`server`** — control plane nodes (embedded etcd HA when there is an odd count ≥ 3).
  - **`agent`** — worker nodes.
- **k3s** is installed with the official Galaxy collection **`k3s.orchestration`** ([k3s-io/k3s-ansible](https://github.com/k3s-io/k3s-ansible)), invoked from `ansible/site.yml`.
- **Secrets** (cluster token) live in **`group_vars/k3s_cluster/secrets.yml`**, preferably encrypted with **Ansible Vault** (see [design_decision_documents/001-secrets-and-ansible-vault.md](design_decision_documents/001-secrets-and-ansible-vault.md)).

## 1. Prerequisites on your control machine

This repo uses [mise](https://mise.jdx.dev/) to pin all tool versions and manage the Python virtual environment. It is the recommended (and tested) way to get a consistent environment.

1. Install **mise**: https://mise.jdx.dev/getting-started.html

   Ensure `mise activate` is in your shell profile (the installer usually adds this). For zsh it should look like:

   ```bash
   eval "$(mise activate zsh)"
   ```

   This is what makes mise automatically activate the project `.venv/` when you `cd` into the repo. If it is not set up, run `. ~/.zshrc` after any change or use `exec zsh` to reload.

2. Clone this repository, then from the repo root:

   ```bash
   mise install           # installs pinned python, helm, kubectl
   mise run deps          # creates .venv, installs ansible + all Python deps, installs Ansible collections
   ```

   After that, `python`, `pip`, `ansible-playbook`, `helm`, and `kubectl` all resolve to `.venv/bin/` or the mise-managed versions — no manual PATH management needed. Verify with `which pip && which ansible`.

3. Ensure **SSH key-based** access to every node as the user you will use for automation (e.g. `matt`).

### What `mise run deps` does

- Runs `pip install -r ansible/requirements.txt` into the project `.venv/` — installs `ansible`, the `kubernetes` Python client, and supporting libraries.
- Runs `ansible-galaxy collection install -r ansible/collections/requirements.yml` — installs `k3s.orchestration`, `kubernetes.core`, and other required collections.

### Why not install ansible globally?

`ansible` is managed as a pip package inside the project `.venv/` rather than using the mise `ansible` plugin. This keeps `ansible`, `kubernetes` (the Python client required by `kubernetes.core` modules), and all other Python dependencies in the same interpreter — no venv path gymnastics required. See `.mise.toml` and `ansible/requirements.txt` for pinned versions.

## 2. Node prerequisites (each host)

1. Supported OS (e.g. Debian/Ubuntu/Raspberry Pi OS) per k3s and collection docs.
2. **OpenSSH** server running; your public key in `~/.ssh/authorized_keys` for the bootstrap user.
3. Meet [K3s installation requirements](https://docs.k3s.io/installation/requirements) (network, swap, etc.) as far as you intend for your lab.

## 3. Bootstrap sudo (one-time, optional but typical)

If `become` requires a password, run the bootstrap play **once** with a sudo password:

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml bootstrap-sudo.yaml --limit <hostname> --ask-become-pass
```

After validation, run without `--limit` for the rest of the fleet. Details: [bootstrap-README.md](../ansible/bootstrap-README.md).

## 4. Bootstrap dedicated `ansible` user (optional, recommended for production-like habits)

To use a non-personal automation account with SSH keys and sudo:

```bash
ansible-playbook -i inventory/hosts.yml bootstrap-user-ansible.yaml --ask-become-pass
```

Then point inventory at `ansible_user: ansible` and the matching private key. See [NOTES.md](NOTES.md) and DDD on least privilege.

## 5. Inventory

1. Edit **`ansible/inventory/hosts.yml`**:
   - Under **`k3s_cluster`**, place hosts in **`server`** or **`agent`**.
   - Set **`ansible_host`** (and **`ansible_user`** / **`ansible_port`** if not in group vars).

2. **k3s-related variables** can live in:
   - **`group_vars/k3s_cluster/main.yml`** (checked into git), and/or
   - **`inventory/hosts.yml`** under `all.vars` or `k3s_cluster.vars` (inventory overrides group_vars when both define the same key).

   You must define a stable **`api_endpoint`** (DNS name or IP) that agents and your workstation can use to reach the Kubernetes API—especially important for HA. Example: `cluster.oue.home` pointing at a load balancer or first server, depending on your design.

## 6. Cluster token and Vault

1. Copy the example secrets file:

   ```bash
   # create token using `openssl` use `yq` to set the token and update `secrets.yaml`
   TOKEN="$(openssl rand -base64 64 | tr -d '[:space:]')" \
      yq '.token = env(TOKEN)' \
         group_vars/k3s_cluster/secrets.yml.example \
         > group_vars/k3s_cluster/secrets.yml
   ```

2. Set **`token`** to a long random value (e.g. `openssl rand -base64 64`).

3. Encrypt:

   ```bash
   ansible-vault encrypt group_vars/k3s_cluster/secrets.yml
   ```

4. `secrets.yml` is **gitignored**; do not commit plaintext tokens.

## 7. Install Ansible collections and Python dependencies

If you followed step 1 and ran `mise run deps`, this is already done. To re-run manually:

```bash
# From the repo root
mise run deps
```

Or individually from the `ansible/` directory:

```bash
pip install -r requirements.txt
ansible-galaxy collection install -r collections/requirements.yml
```

This installs **`k3s.orchestration`**, **`kubernetes.core`**, and their dependencies, plus the `ansible`, `kubernetes`, `PyYAML`, and `jsonpatch` Python packages into `.venv/`.

## 8. Connectivity check

```bash
ansible all -i inventory/hosts.yml -m ping
```

## 9. Run the main playbook

```bash
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

Phases in `site.yml` at the time of writing:

1. **common** role on `k3s_cluster`.
2. **storage** / **rpi_connect** — uncomment plays in `site.yml` when needed.
3. **`import_playbook: k3s.orchestration.site`** — full k3s install via the collection.

## 10. kubectl on the controller

After a successful run, the collection merges kubeconfig into **`~/.kube/config`** with context **`k3s-ansible`** (unless you changed `cluster_context`).

```bash
kubectl config use-context k3s-ansible
kubectl get nodes
```

## 11. Ongoing operations

| Goal | Command |
|------|---------|
| k3s only | `ansible-playbook -i inventory/hosts.yml k3s.orchestration.site --ask-vault-pass` |
| Refresh kubeconfig | `ansible-playbook -i inventory/hosts.yml k3s.orchestration.site --tags kubeconfig --ask-vault-pass` |
| Upgrade k3s | Bump `k3s_version` in vars, then `ansible-playbook -i inventory/hosts.yml k3s.orchestration.upgrade --ask-vault-pass` |

## 12. When this document drifts

Update **SETUP.md** whenever you add a mandatory step (new bootstrap play, new collection, DNS requirement, etc.). Prefer linking to **design_decision_documents** for “why,” and keep this file as the ordered checklist.
