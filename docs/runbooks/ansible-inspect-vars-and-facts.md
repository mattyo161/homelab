# Runbook: Inspect Ansible vars, groups, hostvars, and facts

Use this runbook when you need to debug what Ansible actually sees during a run (inventory merge, Vault-backed vars, runtime facts, and registered values).

## 1) Get merged vars for one host

From `ansible/`:

```bash
ansible-inventory -i inventory/hosts.yml --host mou-mini1 --yaml --ask-vault-pass
```

This is the quickest way to confirm merged values from inventory + `group_vars` + `host_vars` (for example `token`, `api_endpoint`, `ansible_user`).

Get all hosts/groups:

```bash
ansible-inventory -i inventory/hosts.yml --list --yaml --ask-vault-pass
```

## 2) Ad-hoc runtime inspection

Show one variable:

```bash
ansible mou-mini1 -i inventory/hosts.yml -m debug -a "var=api_endpoint" --ask-vault-pass
```

Show all hostvars for one host (large output):

```bash
ansible mou-mini1 -i inventory/hosts.yml -m debug -a "var=hostvars[inventory_hostname]" --ask-vault-pass
```

Show group map:

```bash
ansible localhost -i inventory/hosts.yml -m debug -a "var=groups" --ask-vault-pass
```

## 3) Runtime playbook debugging (recommended)

Create a temporary `debug-vars.yml`:

```yaml
---
- name: Inspect runtime vars
  hosts: server
  gather_facts: true
  tasks:
    - name: Show groups
      ansible.builtin.debug:
        var: groups

    - name: Show first server hostvars
      ansible.builtin.debug:
        var: hostvars[groups['server'][0]]

    - name: Show facts on current host
      ansible.builtin.debug:
        var: ansible_facts
```

Run it:

```bash
ansible-playbook -i inventory/hosts.yml debug-vars.yml --ask-vault-pass -vv
```

## 4) Inspect task-captured values (`register`)

Inside a playbook, print values immediately after capture:

```yaml
- name: Read token file
  ansible.builtin.slurp:
    src: /var/lib/rancher/k3s/server/token
  register: server_token_raw

- name: Show decoded token
  ansible.builtin.debug:
    msg: "{{ server_token_raw.content | b64decode | trim }}"
```

Cross-host example:

```yaml
- name: Show first server value from another host
  ansible.builtin.debug:
    var: hostvars[groups['server'][0]].server_token_raw
```

## 5) Vault behavior reminder

If `group_vars` contains encrypted files (for example `group_vars/k3s_cluster/secrets.yml`), inventory merge requires Vault access even for many ad-hoc commands.

Use one of:

- `--ask-vault-pass`
- `ANSIBLE_VAULT_PASSWORD_FILE=/path/to/file`
- `vault_password_file = ...` in `ansible.cfg` (local-only file, gitignored)

## 6) Quick troubleshooting checklist

- `token` missing in play output? First confirm with `ansible-inventory --host <host> --yaml`.
- `api_endpoint` looks templated in inventory JSON? Confirm evaluated runtime value with `ansible ... -m debug -a "var=api_endpoint"`.
- Need before/after diff? Save inventory output to files and compare.
