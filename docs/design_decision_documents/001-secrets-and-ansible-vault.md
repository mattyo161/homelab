# DDD 001 — Cluster secrets (`secrets.yml`) and Ansible Vault

## Status

Accepted (homelab baseline).

## Context

k3s-ansible requires a **cluster join token** (`token`) and other settings that must not be committed in plaintext to a shared repository. The project also uses **sudo** and may later store **become passwords** or other sensitive variables.

We need a repeatable pattern that:

- Keeps secrets **out of git history** in plaintext.
- Works with **local** and **CI** runs of `ansible-playbook`.
- Is understandable for **future maintainers**.

## Decision

1. Store k3s **`token`** in **`ansible/inventory/group_vars/k3s_cluster/secrets.yml`**, which is **gitignored**.
2. Commit **`inventory/group_vars/k3s_cluster/secrets.yml.example`** with a placeholder and instructions.
3. **Encrypt `secrets.yml` with Ansible Vault** before routine use (`ansible-vault encrypt ...`).
4. Run playbooks with **`--ask-vault-pass`** or a **local-only** `vault_password_file` (never committed).

Non-secret k3s variables (**`k3s_version`**, **`api_endpoint`**, **`cluster_context`**) remain in **`inventory/group_vars/k3s_cluster/main.yml`**, which is safe to commit.

> **Why `inventory/group_vars/` and not `group_vars/` next to `site.yml`?**  
> `site.yml` uses `import_playbook: k3s.orchestration.site` to delegate k3s provisioning to the collection. Ansible switches `playbook_dir` to the collection's directory when executing that imported play, so playbook-adjacent `group_vars/` (next to `site.yml`) is **not loaded** for any of those tasks. Inventory-adjacent `group_vars/` is always loaded regardless of which playbook is executing. See [DDD 003](003-vars-under-inventory-not-playbook.md) for the full explanation.

## Rationale

- **Ansible Vault** ships with Ansible; no extra product is required for the baseline path.
- Separating **`secrets.yml`** from **`main.yml`** keeps reviews simple: one file is always sensitive handling, the other is public config.
- **Gitignore** prevents accidental `git add` of plaintext secrets; Vault adds defense if someone mistakenly tracks the file or shares a backup.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| **Plaintext `secrets.yml` gitignored only** | Simple | No protection if file is copied, emailed, or committed by mistake |
| **`ansible-vault encrypt_string` inline in YAML** | Single file | Noisy diffs; easy to mishandle multiline blocks |
| **Only `-e token=...` on CLI** | Nothing on disk in repo | Leaks in shell history, CI logs unless carefully scrubbed |
| **AWS Secrets Manager / SSM / HashiCorp Vault** | Central rotation, audit, no ciphertext in repo | IAM/network/setup cost; controller must reach the API |
| **CI-only injected env vars** | Secret never in repo | Ties runs to pipeline; harder for ad-hoc laptop fixes |

## Follow-up suggestions

- **CI:** inject vault password via **protected variable** or use **OIDC + external secret store** and render a short-lived vars file in the job (do not print it).
- **Rotation:** document how to change **`token`** on an existing cluster (often disruptive—treat as rebuild or follow upstream k3s docs).
- **Become password:** same Vault file or a separate vaulted file under `group_vars` if you choose not to use NOPASSWD sudo.

## References

- [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [k3s-ansible inventory sample](https://github.com/k3s-io/k3s-ansible/blob/master/inventory-sample.yml)
- [DDD 003 — Keep group_vars under inventory/](003-vars-under-inventory-not-playbook.md)
- [Runbook: Ansible variable scopes and playbook relativity](../runbooks/ansible-variable-scopes-and-playbook-relativity.md)
