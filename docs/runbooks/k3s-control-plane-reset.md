# Runbook: Reset failed k3s control-plane nodes and rejoin

Use when one or more **`server`** hosts have a broken or split k3s install (e.g. wrong cluster, failed HA join) while you intend to keep an **existing** healthy cluster on the **first** inventory server.

**Inventory context:** `server` group order matters for k3s-ansible—the **first** host under `server:` is the bootstrap / reference node for HA. This runbook assumes **`groups['server'][0]`** (e.g. `mou-mini1`) is **healthy** and you are resetting **only** additional control-plane nodes (e.g. `mou-mini2`, `mou-pc1`).

---

## 1. Preconditions

- [ ] **`token`** and **`api_endpoint`** in Ansible match the **existing** cluster (same `group_vars` / Vault you used for the good nodes). Rejoining with a **different** token than the live cluster will not work.
- [ ] From the **first** server host, confirm the cluster you want to keep:
  ```bash
  ssh <first-server>
  sudo kubectl get nodes -o wide
  ```
- [ ] Optional: if the bad nodes still appear as **NotReady** / **Unknown**, consider removing them from the API **after** local uninstall (see step 4):
  ```bash
  sudo kubectl delete node <node-name>
  ```
  Only do this when you are sure you will reinstall k3s on those machines.

---

## 2. Reset using the collection playbook (preferred)

The **k3s-io/k3s-ansible** collection ships **`playbooks/reset.yml`**. When the collection is installed from Galaxy, invoke it by **FQCN** (same pattern as `k3s.orchestration.site`):

```bash
cd ansible

ansible-playbook k3s.orchestration.reset \
  -i inventory/hosts.yml \
  --limit 'mou-mini2,mou-pc1' \
  --ask-vault-pass
```

Notes:

- **`--limit`** restricts teardown to the bad nodes. **Do not** include the first healthy control-plane host unless you intend to **destroy the entire cluster**.
- **`--ask-vault-pass`** is required if you use Vault for `group_vars` (inventory merge), even though reset mostly runs shell uninstalls.
- The playbook runs **`k3s-uninstall.sh`** on hosts in the **`server`** group (and **`k3s-agent-uninstall.sh`** on agents). It also removes the automation user’s **`~/.kube/config`**, **`k3s-install.sh`**, data under **`k3s_server_location`**, and optional **`config.yaml`** when **`server_config_yaml`** is defined.

If uninstall tasks show **skipped** but k3s is still present, use the manual steps in section 3.

---

## 3. Manual cleanup (if reset playbook is not enough)

On **each** host being reset, as root (or sudo):

```bash
# Server nodes (control plane)
sudo /usr/local/bin/k3s-uninstall.sh || true

# If scripts are missing, remove data and binaries by hand (destructive)
sudo systemctl stop k3s 2>/dev/null || true
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s
sudo rm -f /usr/local/bin/k3s /usr/local/bin/kubectl /usr/local/bin/crictl /usr/local/bin/ctr
sudo rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.env
sudo systemctl daemon-reload
```

Remove stale kubeconfig for the user Ansible uses (often **`ansible`**):

```bash
rm -f ~/.kube/config
```

Reboot only if something still holds old CNI state (optional).

---

## 4. Cluster-side cleanup (optional)

If etcd still lists **dead** control-plane members after reinstall attempts, see [k3s HA / etcd troubleshooting](https://docs.k3s.io/datastore/ha-embedded) and remove members properly. For many homelab cases, resetting the **bad nodes** and re-running install with the **same cluster token** is enough once local state is gone.

---

## 5. Re-apply k3s (rejoin)

1. Ensure **Vault** is unlocked and **`token`** / **`api_endpoint`** / **`k3s_version`** are correct.
2. Run the **site** playbook for the **server** group (or full cluster), **without** tearing down the first node.

   **Option A — only the nodes you reset:**

   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml \
     --limit 'mou-mini2,mou-pc1' \
     --ask-vault-pass
   ```

   **Option B — all control-plane hosts** (idempotent on healthy nodes):

   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml \
     --limit 'server' \
     --ask-vault-pass
   ```

3. Confirm join from the **first** server:

   ```bash
   sudo kubectl get nodes -l node-role.kubernetes.io/control-plane=true
   ```

   You want **Ready** and a count matching **`groups['server'] | length`** in inventory.

---

## 6. If verification still fails

- Confirm **`Add token to server config`** is **not** **skipping** on joiner hosts (Vault must be passed to `ansible-playbook`).
- Confirm **`api_endpoint`** resolves and reaches **:6443** from the joiner.
- Confirm you did **not** accidentally run reset or install with **`--limit`** on only a joiner **without** a healthy existing cluster (that can create a one-node cluster).

---

## 7. Post-recovery validation checklist

After `mou-mini2` / `mou-pc1` (or any failed servers) are rejoined, run the following checks from the first server and from your controller:

- [ ] Control-plane membership is complete and healthy:

  ```bash
  sudo kubectl get nodes -l node-role.kubernetes.io/control-plane=true -o wide
  ```

  Expect a **Ready** entry for each host in the inventory `server` group.

- [ ] Core system workloads are healthy:

  ```bash
  sudo kubectl get pods -A -o wide
  ```

  Expect normal `Running` / expected `Completed` states and no persistent `CrashLoopBackOff` / `Pending`.

- [ ] Traefik service-lb pods have recovered across joined nodes (if using default k3s components):

  ```bash
  sudo kubectl -n kube-system get pods -o wide | grep svclb-traefik
  ```

- [ ] Run an idempotency check from controller:

  ```bash
  cd ansible
  ansible-playbook -i inventory/hosts.yml site.yml --limit server --ask-vault-pass
  ```

  Expect mostly `ok` with minimal `changed`. Investigate repeated changes in token/config tasks.

- [ ] Optional full-cluster pass (servers + agents) once control plane is stable:

  ```bash
  ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
  ```

---

## Reference

- Collection playbooks: `k3s.orchestration.site`, `k3s.orchestration.upgrade`, **`k3s.orchestration.reset`**
- Upstream reset source: [k3s-ansible `playbooks/reset.yml`](https://github.com/k3s-io/k3s-ansible/blob/master/playbooks/reset.yml)
- Project notes: [NOTES.md](../NOTES.md) (k3s-ansible, Vault, `--limit` / HA)
