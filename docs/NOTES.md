# Homelab notes

Running log of questions, answers, and practices that come up while building this project. For formal “why we chose X,” see [design_decision_documents/](design_decision_documents/).

---

## Ansible inventory and roles

- **Roles are not assigned in inventory** with arbitrary `roles:` keys under groups (that conflicts with Ansible’s reserved structure and is skipped with warnings). Roles are listed in **playbooks** under `roles:`; inventory only defines **groups and hosts** (plus vars).
- `**hosts:`** in a play selects machines; `**roles:**` lists what runs on them. To change “who gets k3s server vs agent,” move hosts between `**server**` and `**agent**` under `**k3s_cluster**`.

## Inspecting merged variables for a host

- `**ansible-inventory**` shows the **merged** vars for one host (inventory + `group_vars` + `host_vars`). From `ansible/`:
  ```bash
  ansible-inventory -i inventory/hosts.yml --host mou-pc1
  ansible-inventory -i inventory/hosts.yml --host mou-pc1 --yaml
  ```
  With Vault-encrypted `group_vars`, add **`--ask-vault-pass`** or use **`ANSIBLE_VAULT_PASSWORD_FILE`** / **`vault_password_file`** in `ansible.cfg`.
- **Full inventory dump** (all hosts/groups): `ansible-inventory -i inventory/hosts.yml --list --yaml`.
- **Ad hoc `hostvars` during a run** (large output):  
`ansible mou-pc1 -i inventory/hosts.yml -m debug -a "var=hostvars[inventory_hostname]" --ask-vault-pass`

## Facts, hostvars, and debug output strategy

- `**hostvars` is broader than facts:** `hostvars[<host>]` contains merged inventory vars, `group_vars`/`host_vars`, play/role vars, `set_fact`, registered vars, and facts. It is not only `ansible_facts`.
- **Preferred fact access:** use `**ansible_facts[...]`** (for example `ansible_facts['mounts']`, `ansible_facts['devices']`) instead of top-level aliases such as `ansible_mounts` / `ansible_devices`. This is more future-proof as fact injection warnings evolve.
- **Fact availability:** values like mounts/devices exist only when facts are gathered (`gather_facts: true`) or loaded from fact cache.
- **Stdout can be too noisy:** for large structures, write focused JSON/YAML artifacts to files (for example under `ansible/ansible-debug/`) instead of printing full `hostvars` to terminal.
- **Fast fact gathering is normal:** performance comes from SSH connection reuse, host parallelism (`forks`), and relatively lightweight `setup` data; it can still vary with DNS/network and host load.
- **Fact caching behavior:** by default Ansible gathers facts each run and keeps them in memory for that run only. Cross-run persistence requires explicit `fact_caching` configuration in `ansible.cfg`.

## Ordering control-plane bootstrap (HA)

- For “one server first, then the rest,” the usual pattern is **separate inventory groups** (e.g. primary vs additional) and **ordered plays**, or **host vars** + `when:`—not relying on inventory order alone.
- With **k3s-io/k3s-ansible** and **multiple `server` hosts**, the collection handles **embedded etcd HA**; you still want a correct `**api_endpoint`** for a stable API URL.

## Sudo and automation users

- `**Missing sudo password**` means `become: true` without **NOPASSWD** sudo and without `**-K` / `--ask-become-pass`**.
- **Bootstrap pattern:** run a one-time play with `-K` to install `**/etc/sudoers.d/...`** (with `**visudo**` validation), then normal runs can omit `-K`.
- **Least privilege habit:** prefer a dedicated `**ansible`** (or `deploy`) user for automation with passwordless sudo **for that user only**, not for a personal login—see bootstrap playbooks under `ansible/`.

## Secrets

- **Vault runs for `ansible … ping` too:** Anything under `**group_vars/k3s_cluster/*.yml`** is loaded for **every** host in `k3s_cluster` during inventory merge—including `**ansible all -m ping`**. If `**secrets.yml**` is Vault-encrypted, Ansible must decrypt it first, so you see *“Attempting to decrypt but no vault secrets found”* without a password. Fix: pass `**--ask-vault-pass*`*, set `**ANSIBLE_VAULT_PASSWORD_FILE**`, or add `**vault_password_file**` in `**ansible.cfg**` (point at a **gitignored** file such as `**.vault_pass`**). To avoid Vault for quick pings you would have to **stop** keeping encrypted files in auto-loaded `group_vars` (unusual; homelabs usually accept a local vault password file).
- `**ansible_become_password`** can be stored in **Ansible Vault** (encrypted file or `encrypt_string`).
- **Vault ciphertext in private git** is common with a **strong vault password** never committed; **public git + vault** is weak to offline password guessing—prefer **no secrets in repo** for public projects.
- **AWS Secrets Manager / SSM / HashiCorp Vault:** integrate via **lookups** or CI-injected vars; complements or replaces Vault-in-git for stricter setups.

## Auditing “who ran Ansible?”

- On targets, SSH logs usually show `**ansible@<ip>`** and key fingerprint/comment—not automatically the human who ran `ansible-playbook` on a laptop.
- **Stronger attribution:** AWX/AAP, CI job history (who triggered the pipeline), or bastion/SSO SSH.

## Where Ansible runs from

- Spectrum: **laptop** (flexible, weaker audit) → **dedicated control VM** → **CI runner** → **AWX/Semaphore**.
- **GitOps (Flux/Argo)** is often for **Kubernetes workloads**; **host/k3s bootstrap** may still be Ansible or images.

## Tooling / UI options

- **AWX / Ansible Automation Platform:** richest web UI for inventory, credentials, job templates, schedules, RBAC, and audit trail. Best when you want production-like operations and team workflows.
- **Semaphore UI:** lighter self-hosted UI for running Ansible playbooks with inventories and keys; lower setup overhead for homelab, fewer enterprise controls than AWX.
- **Rundeck:** broader runbook/orchestration UI with Ansible integration; useful if you want one UI for mixed automation beyond Ansible.
- **Editor tooling:** VS Code/Cursor Ansible extensions + ansible-lint improve YAML/Jinja authoring; still text-driven but much faster feedback.
- **Expression debugging reality:** most tools do not provide a full live Jinja expression builder for `hostvars/groups`. The most reliable approach remains: export vars/facts to files + run targeted `debug` expressions from a small debug playbook.
- **Current recommendation for this project:** keep the file-based debug workflow (`ansible-debug/*` + `debug-vars.yml`) now; evaluate Semaphore first for low friction, and AWX later if/when you want stronger RBAC/auditing.

## Callback plugin / apt

- `**stdout_callback = yaml`** with old **community.general.yaml** fails on newer collection versions; use `**ansible.builtin.default`** + `**[callback_default] result_format = yaml**` in `ansible.cfg`.
- `**apt update` / `update_cache: true`:** `changed` may mean **cache refreshed**, not a package install—use `**-vv`** or split `**apt**` tasks with `**cache_valid_time**` if you care about semantics.

## Third-party apt repos (example: Cursor)

- A **broken or unsigned** `.list` on a node makes `**apt update` fail for the whole run**, including Ansible `**package`** with `**update_cache: true**`. Fix or remove the offending `**sources.list.d**` entry on the host.

## `group_vars` placement and `import_playbook` from a collection

**TL;DR:** Keep all `group_vars/` and `host_vars/` under `inventory/`, not next to `site.yml`. See [DDD 003](design_decision_documents/003-vars-under-inventory-not-playbook.md) and the [variable scopes runbook](runbooks/ansible-variable-scopes-and-playbook-relativity.md).

- Ansible resolves `group_vars/` relative to **two** paths: the inventory file and the playbook file currently executing. Both are merged — but only at the current `playbook_dir`.
- **`import_playbook: k3s.orchestration.site`** switches `playbook_dir` to the **collection's directory** inside `~/.ansible/collections/...`. Your project's `ansible/group_vars/` is **not** searched for any play inside that imported playbook.
- **`ansible-inventory --host <host>`** merges all sources at parse time — it will show a variable as defined even if it would be missing at runtime inside a collection-imported play. Do not use `ansible-inventory` output alone to confirm runtime availability.
- **Fix:** move all vars to `inventory/group_vars/` and `inventory/host_vars/`. Inventory-adjacent vars travel with the inventory file regardless of which playbook (including collection-imported ones) is running.
- A file named `group_vars/secrets.yml` (no group subdirectory) is **not** a global secrets file — it applies only to a group literally named `secrets`. Use `group_vars/k3s_cluster/secrets.yml` or `group_vars/all.yml` instead.

## `--limit` and HA server joins: always include the first server

When `token` is **not** in vault, the cluster join token is read from `/var/lib/rancher/k3s/server/token` on `groups['server'][0]` (the first inventory server) and stored as `random_token` via `set_fact` — an **in-memory-only** fact that exists only for the duration of that Ansible run.

Joiner servers (any server that is not `groups['server'][0]`) retrieve it via:

```jinja
hostvars[groups[server_group][0]].random_token
```

**`hostvars` always contains all inventory hosts** regardless of `--limit`. But `random_token` is a `set_fact` — it is only present if the first server **actually executed tasks** during this run. If you run `--limit mou-mini2` alone, mou-mini1 never runs, `random_token` is never set, the `when:` condition on the joiner is false, no token goes into `config.yaml`, and k3s generates a fresh random secret — creating a new one-node cluster instead of joining the existing one.

**Rules:**

- When adding or re-provisioning joiner servers **without** `token` in vault: always use `--limit server` (full group) or explicitly include `groups['server'][0]` in `--limit`.
- When `token` is in vault: `--limit` to individual joiners is safe because the vault-decrypted token is available on every host without needing a runtime `set_fact` from the first server.
- `random_token` is not persisted anywhere. It cannot be looked up after the run that created it. If you want stable, independently-runnable joins, keep `token` in vault.

See also: [k3s-control-plane-reset runbook](runbooks/k3s-control-plane-reset.md) (re-join section).

## k3s-ansible collection

- Playbook FQCN: `**k3s.orchestration.site**`; upgrade: `**k3s.orchestration.upgrade**`.
- Requires `**token**`, `**k3s_version**`, `**api_endpoint**` (and inventory group layout `**server**` / `**agent**` under `**k3s_cluster**`). See **SETUP.md** and **001-secrets-and-ansible-vault.md**.
- `**token` must be the literal variable name** at the **top level** of decrypted `group_vars/k3s_cluster/secrets.yml` (e.g. `token: "..."`, not nested under another key). Confirm Ansible sees it:  
`ansible-inventory -i inventory/hosts.yml --host mou-pc1 --yaml` (with vault unlocked) and look for `**token:`**.
- **First vs additional server nodes:** In `inventory/hosts.yml`, the **first host listed** under `**server:`** is treated as the **first control-plane node**; any other `server` host uses a different task block in the upstream role. If `**token` is missing** on those additional servers, you can get `**'token' is undefined`** on the `lineinfile` task (upstream used `token | regex_escape` there but `token | default('')` on the first server). A one-line local fix is to change that `regexp` to use `**token | default('') | regex_escape**` in `~/.ansible/collections/ansible_collections/k3s/orchestration/roles/k3s_server/tasks/main.yml` (re-applying `**ansible-galaxy collection install**` overwrites the collection).
- **Upstream deprecations / bugs (not our playbooks):** Warnings such as `**INJECT_FACTS_AS_VARS`** and use of `**ansible_hostname**` come from **k3s-io/k3s-ansible** under `~/.ansible/collections/...`, not from `homelab/ansible`. **Current approach:** ignore those messages until they matter. **Future options (pick when ready):**
  1. **Ignore or suppress** — e.g. `deprecation_warnings = False` in `ansible.cfg` (hides all deprecations, not only this collection).
  2. **Local patch** after each `ansible-galaxy collection install` — quick for homelab, easy to lose on reinstall.
  3. **Upstream PR** to [k3s-io/k3s-ansible](https://github.com/k3s-io/k3s-ansible) (e.g. `ansible_hostname` → `ansible_facts['hostname']`, align `lineinfile` with `token | default('')`).
  4. **Fork** the repo, apply fixes, point `**collections/requirements.yml`** at the fork (git URL + branch/tag), to own the timeline and learn the Ansible layout.

---

*Add new dated or titled sections below as the project evolves.*