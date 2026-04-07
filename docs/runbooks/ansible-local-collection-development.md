# Runbook: Developing an Ansible collection locally (without reinstalling from Galaxy)

Use this when you have a **forked or local copy** of a collection (e.g. `k3s-ansible`) and want
Ansible to use **that checkout** directly — no `ansible-galaxy collection install` on every edit.

---

## Background

`ansible-galaxy collection install` writes a collection to a path in `COLLECTIONS_PATHS` and
Ansible finds it there at runtime. By default:

```
~/.ansible/collections/ansible_collections/<namespace>/<name>/
```

For local development you want Ansible to look **inside your project's `collections/` folder first**,
where you can place a symlink pointing at your Git checkout.

---

## Step 1 — Create the directory structure

The path Ansible expects is always:

```
<collections_root>/ansible_collections/<namespace>/<name>/
```

For `k3s.orchestration` (namespace `k3s`, name `orchestration`):

```bash
mkdir -p ansible/collections/ansible_collections/k3s
```

---

## Step 2 — Symlink your local checkout

```bash
ln -sfn /Users/matt/Projects/k8/k3s-ansible \
  /Users/matt/Projects/k8/homelab/ansible/collections/ansible_collections/k3s/orchestration
```

Verify:

```bash
ls -la ansible/collections/ansible_collections/k3s/
# orchestration -> /Users/matt/Projects/k8/k3s-ansible
```

The symlink target must be the **collection root** — the directory that contains `galaxy.yml`
(and `roles/`, `playbooks/`, etc.).

---

## Step 3 — Tell Ansible to search your project's `collections/` first

### Option A — `ansible.cfg` (recommended for a project)

```ini
[defaults]
collections_path = ./collections:~/.ansible/collections:/usr/share/ansible/collections
```

> **Key name gotcha:** the ini key is `collections_path` (singular), **not** `collections_paths`.
> Ansible silently ignores unrecognized keys, so the plural form falls back to the built-in default
> with no warning. See [Troubleshooting](#troubleshooting-ansible-config) below.

`./collections` is relative to the **working directory** when you run `ansible-playbook`
(i.e. your `ansible/` project root). Use an absolute path if you run from different directories.

### Option B — Environment variable

```bash
export ANSIBLE_COLLECTIONS_PATH=/path/to/ansible/collections:~/.ansible/collections
```

Environment variables override `ansible.cfg`. Useful for one-off overrides without editing the file.

### Option C — `requirements.yml` with `type: dir` (no symlink needed)

```yaml
# collections/requirements.yml
collections:
  - name: /Users/matt/Projects/k8/k3s-ansible
    type: dir
```

Then install:

```bash
ansible-galaxy collection install -r collections/requirements.yml --force -p ./collections
```

This **copies** the collection into `./collections` rather than symlinking, so edits to the source
repo are not reflected until you re-run the install. Less useful for active development.

### Option D — Pin to a git branch (for shared/CI use)

```yaml
# collections/requirements.yml
collections:
  - name: https://github.com/yourfork/k3s-ansible.git
    type: git
    version: fix-token-initialization
```

Ansible fetches the branch from GitHub. Use this when the machine running Ansible does not have a
local checkout (CI runners, other team members). Not for tight edit/test loops.

---

## Step 4 — Verify Ansible sees the right collection

```bash
# Check which paths Ansible resolves at startup
ansible --version | grep 'collection location'
# Should include your project's collections/ path first

# Confirm the collection is found and which directory it resolves to
ansible-galaxy collection list k3s.orchestration
# Should show the path under your project, not ~/.ansible/collections
```

---

## Troubleshooting ansible-config {#troubleshooting-ansible-config}

When an `ansible.cfg` setting appears to be silently ignored, use these commands to diagnose.

### Show what config file Ansible is using

```bash
ansible --version | head -3
# config file = /path/to/ansible.cfg  ← must point at your project's file
```

If it shows a different file (or `None`), Ansible is not finding your `ansible.cfg`. It searches:
1. `ANSIBLE_CONFIG` environment variable (absolute path)
2. `./ansible.cfg` (current working directory)
3. `~/.ansible.cfg`
4. `/etc/ansible/ansible.cfg`

Run `ansible-playbook` from the directory that **contains** `ansible.cfg`.

### Show all settings that differ from defaults

```bash
ansible-config dump --only-changed
```

Each line shows `SETTING_NAME(source) = value`. If a setting you added to `ansible.cfg` does not
appear here with `(your_ansible.cfg)` as the source, it is either:
- Using the wrong key name (see below)
- In the wrong `[section]`
- Being overridden by an environment variable

### Find the correct key name and section for any setting

```bash
# Look up the ini key, section, and env var for a config setting
ansible-config list | grep -A 20 'COLLECTIONS_PATHS'
```

Output example:

```yaml
COLLECTIONS_PATHS:
  description: "Colon-separated paths..."
  env:
  - name: ANSIBLE_COLLECTIONS_PATH
  ini:
  - key: collections_path      # ← this is what goes in ansible.cfg
    section: defaults           # ← this is the [section] it belongs under
```

> **Lesson learned on this project:** `COLLECTIONS_PATHS` maps to the ini key `collections_path`
> (singular). Using `collections_paths` (plural) in `ansible.cfg` is silently ignored — Ansible
> falls back to the default `~/.ansible/collections` with no warning.

### Show the resolved value of a specific setting

```bash
ansible-config dump | grep -i COLLECTIONS_PATHS
# COLLECTIONS_PATHS(default) = [...]       ← not picking up your cfg
# COLLECTIONS_PATHS(/path/ansible.cfg) = [...] ← correctly loaded
```

The source in parentheses tells you exactly where the value came from.

### Check for environment variable overrides

```bash
env | grep ANSIBLE
# ANSIBLE_COLLECTIONS_PATH=...  ← overrides ansible.cfg if set
```

Environment variables take priority over `ansible.cfg`. If one is set, either unset it or make sure
it includes your local path.

---

## Workflow summary

```
Edit roles/tasks in k3s-ansible checkout
         ↓
ansible-playbook site.yml    (no reinstall needed)
         ↓
Ansible resolves k3s.orchestration via symlink → your checkout
```

When you are satisfied with changes, commit them to the fork and optionally update
`collections/requirements.yml` to point at the new commit/branch for reproducible installs on
other machines.

---

## Reference

- [Ansible: configuring collections paths](https://docs.ansible.com/ansible/latest/collections_guide/collections_installing.html)
- [Ansible: configuration file reference](https://docs.ansible.com/ansible/latest/reference_appendices/config.html)
- `ansible-config list` — full list of all config settings with ini keys, env vars, and defaults
- `ansible-config dump --only-changed` — shows only settings that differ from compiled-in defaults
