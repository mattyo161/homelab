# DDD 002 — k3s-io k3s-ansible (Galaxy) vs custom `roles/k3s*`

## Status

Accepted.

## Context

The repository previously used **custom roles** (`k3s`, `k3s_server`, `k3s_agent`) wrapping `curl | get.k3s.io`, token slurping, and manual ordering. Maintaining that duplicates upstream logic (HA, upgrades, airgap options, kubeconfig handling) and drifts from community fixes.

## Decision

- Use the official **`k3s.orchestration`** collection from **[k3s-io/k3s-ansible](https://github.com/k3s-io/k3s-ansible)**.
- Install via **`ansible/collections/requirements.yml`** (git pin to a tag or commit).
- Integrate with **`import_playbook: k3s.orchestration.site`** from `site.yml`.
- **Remove** custom k3s plays from the main flow; **legacy roles** may remain in the tree unused until deleted after validation.

## Rationale

- **Upstream alignment:** HA embedded etcd, upgrade playbook, kubeconfig merge, and OS coverage stay current with the wider k3s community.
- **Less custom code** to security-review and test on every k3s release.
- **Clear contract:** inventory shape (`k3s_cluster` → `server` / `agent`) and variables match published samples.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| **Keep custom roles only** | Full control, minimal dependencies | Ongoing maintenance; HA/upgrade edge cases |
| **techno-tim / other k3s-ansible forks** | Extra features (e.g. MetalLB, kube-vip) | Different contract; heavier opinionated stack |
| **k3sup, manual scripts** | Fast one-off | Poor idempotency and fleet repeatability |
| **Immutable images + no Ansible for k3s** | Very reproducible | Requires image pipeline; heavier for homelab iteration |

## Follow-up suggestions

- Delete **`roles/k3s`**, **`roles/k3s_server`**, **`roles/k3s_agent`** once the collection path is proven in production.
- Pin **collection version** in `requirements.yml` and bump deliberately after reading upstream release notes.

## References

- Collection install: `ansible-galaxy collection install -r collections/requirements.yml`
- Playbooks: `k3s.orchestration.site`, `k3s.orchestration.upgrade`
