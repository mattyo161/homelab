# Homelab notes

Running log of questions, answers, and practices that come up while building this project. For formal “why we chose X,” see [design_decision_documents/](design_decision_documents/).

---

## Ansible inventory and roles

- **Roles are not assigned in inventory** with arbitrary `roles:` keys under groups (that conflicts with Ansible’s reserved structure and is skipped with warnings). Roles are listed in **playbooks** under `roles:`; inventory only defines **groups and hosts** (plus vars).
- **`hosts:`** in a play selects machines; **`roles:`** lists what runs on them. To change “who gets k3s server vs agent,” move hosts between **`server`** and **`agent`** under **`k3s_cluster`**.

## Ordering control-plane bootstrap (HA)

- For “one server first, then the rest,” the usual pattern is **separate inventory groups** (e.g. primary vs additional) and **ordered plays**, or **host vars** + `when:`—not relying on inventory order alone.
- With **k3s-io/k3s-ansible** and **multiple `server` hosts**, the collection handles **embedded etcd HA**; you still want a correct **`api_endpoint`** for a stable API URL.

## Sudo and automation users

- **`Missing sudo password`** means `become: true` without **NOPASSWD** sudo and without **`-K` / `--ask-become-pass`**.
- **Bootstrap pattern:** run a one-time play with `-K` to install **`/etc/sudoers.d/...`** (with **`visudo`** validation), then normal runs can omit `-K`.
- **Least privilege habit:** prefer a dedicated **`ansible`** (or `deploy`) user for automation with passwordless sudo **for that user only**, not for a personal login—see bootstrap playbooks under `ansible/`.

## Secrets

- **Vault runs for `ansible … ping` too:** Anything under **`group_vars/k3s_cluster/*.yml`** is loaded for **every** host in `k3s_cluster` during inventory merge—including **`ansible all -m ping`**. If **`secrets.yml`** is Vault-encrypted, Ansible must decrypt it first, so you see *“Attempting to decrypt but no vault secrets found”* without a password. Fix: pass **`--ask-vault-pass`**, set **`ANSIBLE_VAULT_PASSWORD_FILE`**, or add **`vault_password_file`** in **`ansible.cfg`** (point at a **gitignored** file such as **`.vault_pass`**). To avoid Vault for quick pings you would have to **stop** keeping encrypted files in auto-loaded `group_vars` (unusual; homelabs usually accept a local vault password file).
- **`ansible_become_password`** can be stored in **Ansible Vault** (encrypted file or `encrypt_string`).
- **Vault ciphertext in private git** is common with a **strong vault password** never committed; **public git + vault** is weak to offline password guessing—prefer **no secrets in repo** for public projects.
- **AWS Secrets Manager / SSM / HashiCorp Vault:** integrate via **lookups** or CI-injected vars; complements or replaces Vault-in-git for stricter setups.

## Auditing “who ran Ansible?”

- On targets, SSH logs usually show **`ansible@<ip>`** and key fingerprint/comment—not automatically the human who ran `ansible-playbook` on a laptop.
- **Stronger attribution:** AWX/AAP, CI job history (who triggered the pipeline), or bastion/SSO SSH.

## Where Ansible runs from

- Spectrum: **laptop** (flexible, weaker audit) → **dedicated control VM** → **CI runner** → **AWX/Semaphore**.
- **GitOps (Flux/Argo)** is often for **Kubernetes workloads**; **host/k3s bootstrap** may still be Ansible or images.

## Callback plugin / apt

- **`stdout_callback = yaml`** with old **community.general.yaml** fails on newer collection versions; use **`ansible.builtin.default`** + **`[callback_default] result_format = yaml`** in `ansible.cfg`.
- **`apt update` / `update_cache: true`:** `changed` may mean **cache refreshed**, not a package install—use **`-vv`** or split **`apt`** tasks with **`cache_valid_time`** if you care about semantics.

## Third-party apt repos (example: Cursor)

- A **broken or unsigned** `.list` on a node makes **`apt update` fail for the whole run**, including Ansible **`package`** with **`update_cache: true`**. Fix or remove the offending **`sources.list.d`** entry on the host.

## k3s-ansible collection

- Playbook FQCN: **`k3s.orchestration.site`**; upgrade: **`k3s.orchestration.upgrade`**.
- Requires **`token`**, **`k3s_version`**, **`api_endpoint`** (and inventory group layout **`server`** / **`agent`** under **`k3s_cluster`**). See **SETUP.md** and **001-secrets-and-ansible-vault.md**.

---

_Add new dated or titled sections below as the project evolves._
