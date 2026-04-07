# DDD 003 — Keep `group_vars` and `host_vars` under `inventory/`, not next to playbooks

## Status

Accepted (homelab baseline).

## Context

Ansible resolves `group_vars/` and `host_vars/` relative to **two** locations:

1. **Next to the playbook file** (`playbook_dir/group_vars/`)
2. **Next to the inventory file** (`inventory_dir/group_vars/`)

When all plays are in a single top-level playbook (e.g. `site.yml`), both locations work equally well. The problem arises when a playbook uses **`import_playbook`** to pull in a play from a **collection**.

### What happens with `import_playbook: k3s.orchestration.site`

`import_playbook` does **not** run the imported play in the context of the calling playbook's directory. It runs it in the context of the **collection's directory** (deep inside `ansible_collections/k3s/orchestration/playbooks/`). Ansible therefore looks for `group_vars/` relative to **that path** — not relative to your project's `ansible/` directory.

This means:

- **`ansible/group_vars/k3s_cluster/secrets.yml`** → found and loaded for phases run directly in `ansible/site.yml`
- **`ansible/group_vars/k3s_cluster/secrets.yml`** → **not found** for the plays t imported from `k3s.orchestration.site`

The result is a variable like `token` appearing **defined** in Phase 1 (your own plays) but **undefined** in Phase 4 (the imported collection play), even though nothing changed in the inventory or secrets files.

This was the root cause of extended debugging confusion on this project: `ansible-inventory` showed `token` correctly because it merges all sources at inventory-load time, but the runtime variable availability inside a play depends on which `playbook_dir` Ansible uses for that play.

## Decision

1. Keep **all `group_vars/` and `host_vars/` under `inventory/`**, not next to `site.yml` or other top-level playbooks.
2. The canonical path for k3s cluster vars is:

   ```
   ansible/
     inventory/
       hosts.yml
       group_vars/
         k3s_cluster/
           main.yml          ← k3s_version, api_endpoint, cluster_context (committed)
           secrets.yml       ← vault-encrypted token (gitignored)
           secrets.yml.example
       host_vars/
         <hostname>/         ← per-host overrides if ever needed
   ```

3. **Do not** rely on `ansible/group_vars/` for variables that need to be available in collection-imported plays.

## Rationale

- **Inventory-adjacent vars travel with the inventory**, not with the playbook. Because `inventory/hosts.yml` is the single source of truth for which hosts exist, keeping vars next to it creates a self-contained unit: `inventory/` contains everything needed to describe the fleet — topology, vars, and secrets.
- **`import_playbook` from a collection changes `playbook_dir`** at the point the imported play runs; there is no way to override this without hacking collection internals or writing a wrapper play that avoids `import_playbook`.
- **`ansible-inventory --host <host>`** merges both inventory-adjacent and playbook-adjacent `group_vars`, so the inventory inspection tool always shows the "full merged" picture regardless of which path vars are in. This made the bug hard to detect with `ansible-inventory` alone.
- **Simpler mental model:** one location for all vars, consistent across ad-hoc commands, playbooks, and imported collection plays.

## Consequences

- If you later add playbook-adjacent `group_vars/` files for any reason, they will only apply to plays running directly from `ansible/` — not to imported collection plays. Treat playbook-adjacent `group_vars/` as a trap for future confusion.
- The `ansible/group_vars/` directory can be removed entirely to avoid ambiguity. Any files currently there should be migrated to `inventory/group_vars/` or deleted.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| **`group_vars/` next to `site.yml`** | Conventional for single-playbook projects | Breaks silently when `import_playbook` from a collection is used |
| **Both locations (playbook + inventory)** | Redundant coverage | Inconsistent; precedence surprises; duplicate maintenance |
| **`-e @vars_file` on every run** | Works everywhere | Fragile, manual, easy to forget |
| **Avoid `import_playbook`; use role includes instead** | Keeps one `playbook_dir` | Requires replicating collection's play ordering and host selection logic |
| **`ANSIBLE_VARS_PLUGINS`** | Global custom var paths | Complex; non-standard; breaks portability |

## References

- [Ansible variable precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
- [Ansible `group_vars` loading](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables)
- [k3s-io/k3s-ansible#527](https://github.com/k3s-io/k3s-ansible/issues/527) — related upstream issue where `to_nice_yaml` with vault-encrypted vars also produced surprising behavior when the play context changed
- DDD 001 — Secrets and Ansible Vault
- DDD 002 — k3s.orchestration collection vs custom roles
