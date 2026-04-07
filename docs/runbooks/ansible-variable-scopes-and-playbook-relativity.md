# Runbook: Ansible variable scopes and playbook-relative `group_vars`

## Purpose

Explain why variables appear correctly in `ansible-inventory` output but are missing (undefined) at runtime — specifically when using `import_playbook` from a collection. This runbook is the "lessons learned" companion to [DDD 003](../design_decision_documents/003-vars-under-inventory-not-playbook.md).

---

## Quick diagnosis

**Symptom:** A variable (e.g. `token`) shows up in `ansible-inventory --host <host>` but a task fails with `'token' is undefined` or the variable appears empty when the play runs.

**Most likely cause:** The variable is in `ansible/group_vars/` (playbook-adjacent), but the failing task runs inside a **collection-imported play** whose `playbook_dir` is inside the collection, not your project.

---

## Background: where Ansible looks for `group_vars`

Ansible loads `group_vars/` from **two** locations per run:

| Location | Resolved relative to |
|----------|----------------------|
| `group_vars/` | The **playbook file** currently executing (`playbook_dir`) |
| `group_vars/` | The **inventory file** (`inventory_dir`) |

Both are merged into the variable set. When your entire project runs from a single playbook in one directory, both point to the same root and there is no conflict.

### The `import_playbook` from a collection changes `playbook_dir`

```yaml
# ansible/site.yml
- name: My own play        # playbook_dir = ansible/
  hosts: k3s_cluster
  roles: [common]

- import_playbook: k3s.orchestration.site   # playbook_dir = .../ansible_collections/k3s/orchestration/playbooks/
```

When `import_playbook` resolves `k3s.orchestration.site`, Ansible finds the playbook file **inside the installed collection**. From that point, `playbook_dir` is the collection's playbooks directory — not your `ansible/` folder.

Ansible then looks for `group_vars/` relative to **that path**:

```
~/.ansible/collections/ansible_collections/k3s/orchestration/playbooks/group_vars/  # does not exist
```

Your `ansible/group_vars/` is **never searched** for plays imported from the collection.

### Why `ansible-inventory` is misleading here

`ansible-inventory` merges **all** variable sources at inventory-parse time — it combines both inventory-adjacent and playbook-adjacent `group_vars`. So:

```bash
ansible-inventory -i inventory/hosts.yml --host mou-mini1 --yaml
```

Will show `token` in the output even if `token` is only in `ansible/group_vars/k3s_cluster/secrets.yml`.

This does **not** mean that `token` will be available inside `k3s.orchestration.site` at runtime. The inventory inspection tool and the runtime variable loading are different code paths.

---

## Variable precedence order (simplified, lowest to highest)

1. Role defaults (`roles/*/defaults/main.yml`)
2. Inventory `group_vars` (inventory-adjacent)
3. Inventory `host_vars` (inventory-adjacent)
4. Playbook `group_vars` (playbook-adjacent) ← **not loaded for collection-imported plays**
5. Playbook `host_vars` (playbook-adjacent) ← **not loaded for collection-imported plays**
6. Play vars (`vars:` in a play)
7. Role vars (`roles/*/vars/main.yml`)
8. `set_fact` / registered vars
9. Extra vars (`-e` / `--extra-vars`) ← always wins

For collection-imported plays, items 4 and 5 are effectively absent.

---

## Diagnosing a missing variable

### Step 1 — Check where the var is defined

```bash
# From ansible/
ansible-inventory -i inventory/hosts.yml --host mou-mini1 --yaml | grep token
```

If it shows up here, the var is loaded at inventory time.

### Step 2 — Find which file provides it

```bash
# List all group_vars files Ansible might load
find . inventory/ -path '*/group_vars/*' -name '*.yml' | sort
```

Note whether the file is under `inventory/group_vars/` or `./group_vars/` (playbook-adjacent).

### Step 3 — Identify which play the failing task belongs to

Look at the task output header:

```
TASK [k3s_server : Add token to server config] ****
```

If the role name is prefixed with a collection (`k3s_server` from `k3s.orchestration`), the task is running inside the collection's play — playbook-adjacent `group_vars` are not loaded.

### Step 4 — Move the var to `inventory/group_vars/`

```bash
# Before: variable only in playbook-adjacent location
ansible/group_vars/k3s_cluster/secrets.yml

# After: variable in inventory-adjacent location
ansible/inventory/group_vars/k3s_cluster/secrets.yml
```

Re-run. The variable should now be available in all plays, including collection-imported ones.

---

## This project's convention

All `group_vars/` and `host_vars/` live under `inventory/`:

```
ansible/
  inventory/
    hosts.yml
    group_vars/
      k3s_cluster/
        main.yml          ← public vars: k3s_version, api_endpoint, cluster_context
        secrets.yml       ← vault-encrypted: token (gitignored)
        secrets.yml.example
    host_vars/            ← per-host overrides (if ever needed)
```

Do **not** rely on `ansible/group_vars/` for any variable that must be visible to collection-imported plays. See [DDD 003](../design_decision_documents/003-vars-under-inventory-not-playbook.md) for the full design rationale.

---

## Common mistakes and fixes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `group_vars/` next to `site.yml`, not under `inventory/` | Var defined in inventory inspection, undefined at runtime in collection play | Move file to `inventory/group_vars/` |
| `group_vars/secrets.yml` (no group subfolder) | Var applies only to a group named `secrets` (does not exist) | Move to `group_vars/k3s_cluster/secrets.yml` or `group_vars/all.yml` |
| Vault-encrypted var in `group_vars/` passed through `to_nice_yaml` | Config file on node contains `!vault` ciphertext instead of the value | Use `token \| string` to coerce before building the config dict (see [k3s-io/k3s-ansible#527](https://github.com/k3s-io/k3s-ansible/issues/527)) |
| `ansible-inventory` shows var correctly so "it must be loaded" | False confidence; runtime loading for collection plays differs from inventory inspection | Always verify with a debug play inside the collection-imported play context, not just `ansible-inventory` |
| `host_vars/secrets.yml` as a "global secrets file" | Vars apply only to a host named `secrets` | Move to `inventory/group_vars/<group>/secrets.yml` |

---

## Checking variable availability at runtime (not just inventory parse time)

Add a debug play **before** the collection-imported play in `site.yml` (remove after confirming):

```yaml
- name: Debug token availability
  hosts: server
  gather_facts: false
  tasks:
    - name: Show token (masked)
      ansible.builtin.debug:
        msg: "token is {{ 'defined' if token is defined else 'UNDEFINED' }}"
```

Or run the debug ad-hoc for a quick check:

```bash
ansible server -i inventory/hosts.yml \
  -m debug -a "var=token" \
  --ask-vault-pass
```

---

## References

- [DDD 003 — Keep group_vars under inventory/](../design_decision_documents/003-vars-under-inventory-not-playbook.md)
- [DDD 001 — Secrets and Ansible Vault](../design_decision_documents/001-secrets-and-ansible-vault.md)
- [Ansible variable precedence docs](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
- [Ansible inventory group_vars docs](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables)
