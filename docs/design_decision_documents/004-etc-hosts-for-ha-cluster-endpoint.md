# DDD 004 — /etc/hosts entries for the HA cluster endpoint


| Field            | Value                                                                                                                                                                      |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Status           | Accepted                                                                                                                                                                   |
| Date             | 2026-04-07                                                                                                                                                                 |
| Deciders         | Matt                                                                                                                                                                       |
| Related runbooks | [k3s-agent-cluster-connectivity-troubleshooting](../runbooks/k3s-agent-cluster-connectivity-troubleshooting.md), [cli-tools-reference](../runbooks/cli-tools-reference.md) |


---

## Context

The homelab k3s cluster uses a DNS hostname (`cluster.oue.home`) as the `api_endpoint` rather than a single server IP. This lets the cluster endpoint survive the loss of any one server — the HA embedded etcd cluster continues serving requests from the remaining nodes.

However, `cluster.oue.home` must resolve to one or more server IPs on every node in the cluster. This resolution is handled by Pi-hole (local DNS at `192.168.5.163`), but three failure modes were discovered during setup:

1. **Go runtime bypasses NSS.** k3s is a Go binary. Its DNS resolver reads `/etc/resolv.conf` directly and does not go through glibc/NSS. This means `nsswitch.conf` ordering (`files dns`), `mdns4_minimal`, and `systemd-resolved` stubs are all bypassed. Only `/etc/resolv.conf` nameservers (and `/etc/hosts`) are used.
2. **Backup nameserver poisoning.** When `/etc/resolv.conf` contains two nameservers (e.g. Pi-hole `192.168.5.163` and router `192.168.1.1`), Go's resolver may fall through to the router if Pi-hole returns a response with `TTL=0` (which causes immediate re-query) or times out. The router has no record of `cluster.oue.home` and returns `NXDOMAIN`. This produced intermittent `lookup cluster.oue.home: no such host` errors that were hard to reproduce because `nslookup` and `getent` succeeded (they go through NSS/libc, not Go's resolver).
3. **DNS is a runtime dependency.** If Pi-hole is restarting, unreachable, or misconfigured, every node in the cluster loses the ability to connect to the API endpoint. This is particularly problematic for agent nodes attempting to join or re-join after a reset.

---

## Decision

All k3s cluster nodes have `/etc/hosts` entries mapping each server's IP to `cluster.oue.home`.

```
# BEGIN ANSIBLE MANAGED: cluster.oue.home
192.168.5.151 cluster.oue.home
192.168.5.165 cluster.oue.home
192.168.5.166 cluster.oue.home
# END ANSIBLE MANAGED: cluster.oue.home
```

These entries are managed by the `ansible/hosts.yml` playbook using `blockinfile` for atomic idempotent updates. The playbook is separate from `site.yml` so it can be run independently to refresh entries (e.g. after an IP change).

---

## Rationale

### Why multiple IPs for the same hostname?

Linux reads `/etc/hosts` sequentially. When multiple lines map different IPs to the same hostname, all IPs are returned by `getaddrinfo()`. Go's DNS resolver also returns all matching `/etc/hosts` entries. The k3s agent and server processes attempt connections to each IP in turn.

This provides the same failover behaviour the DNS round-robin approach was intended to give, but without any dependency on DNS infrastructure at connection time.

### Why not rely on Pi-hole DNS alone?


| Concern                  | DNS only                       | /etc/hosts                       |
| ------------------------ | ------------------------------ | -------------------------------- |
| Pi-hole restart window   | API unreachable                | Unaffected                       |
| Router as backup DNS     | `NXDOMAIN` for `.oue.home`     | Unaffected                       |
| Go resolver bypasses NSS | May use router fallback        | Reads /etc/hosts directly        |
| TTL=0 from Pi-hole       | Aggressive re-queries, timeout | No TTL concern                   |
| Node added to cluster    | Must update DNS record         | Run `ansible-playbook hosts.yml` |


### Why not a load balancer VIP (keepalived / kube-vip)?

A proper VIP (single IP that floats between servers) is the ideal HA solution, but adds:

- An additional component to configure and maintain
- Complexity in the Ansible roles
- Risk of split-brain if keepalived is misconfigured

Multiple `/etc/hosts` entries are simpler, require no additional services, and are sufficient for the homelab use case where losing one server is the primary concern. A VIP could be added in a future iteration if more deterministic failover is needed.

### Why not hardcode IPs in inventory?

IPs in this homelab are DHCP-assigned. Using `ansible.builtin.setup` to gather the IP at playbook runtime means the hosts file reflects the actual current IP. If a server is replaced or its IP changes, re-running `ansible-playbook hosts.yml` brings all nodes up to date automatically.

---

## Implementation

`ansible/hosts.yml` playbook:

```yaml
- name: Configure /etc/hosts for HA cluster endpoint
  hosts: k3s_cluster
  gather_facts: true
  become: true
  tasks:
    - name: Gather facts from server nodes (for IP lookup)
      # Delegates setup to each server so their IPs are in hostvars even when
      # --limit excludes the server group.
      ansible.builtin.setup:
      delegate_to: "{{ item }}"
      delegate_facts: true
      loop: "{{ groups['server'] }}"
      run_once: true

    - name: Write cluster server IPs to /etc/hosts (atomic block replace)
      ansible.builtin.blockinfile:
        path: /etc/hosts
        marker: "# {mark} ANSIBLE MANAGED: {{ api_endpoint }}"
        block: |
          {% for host in groups['server'] %}
          {{ hostvars[host]['ansible_facts']['default_ipv4']['address'] }} {{ api_endpoint }}
          {% endfor %}
```

Key implementation decisions:

- **`blockinfile` over `lineinfile`:** Atomically replaces the entire block in a single write. No window where some entries are present and others are missing.
- **`delegate_to` + `delegate_facts: true` + `run_once: true` for fact gathering:** When `--limit mou-pi5` is used, `gather_facts: true` on the play would only gather facts for `mou-pi5`. By explicitly delegating `setup` to each server and storing results with `delegate_facts: true`, server IPs are available in `hostvars` regardless of the `--limit` on the invoking play. `run_once: true` prevents the delegation loop from being executed once per target host.
- **`api_endpoint` as marker key:** The `blockinfile` marker includes `api_endpoint`, so if the cluster endpoint hostname ever changes, the old block is cleanly replaced rather than accumulating stale entries.
- **Separate playbook (not part of `site.yml`):** Allows targeted re-runs (`--limit`) for testing on a single node, and makes it easy to add or refresh entries after IP changes without re-running the full site playbook.

---

## Consequences

### Positive

- k3s agent and server joins are resilient to Pi-hole downtime.
- Go's DNS resolver reliably finds the cluster endpoint without depending on nameserver ordering or TTL handling.
- The same playbook populates all nodes — no per-host manual configuration.
- Adding `/etc/hosts` entries for `cluster.oue.home` does not prevent Pi-hole from also serving the record; both can coexist.

### Negative / tradeoffs

- If a server's IP changes (DHCP lease renewal with a new IP), the cluster may become unreachable until `ansible-playbook hosts.yml` is re-run. Mitigation: assign static DHCP leases in the router for all server nodes.
- Having multiple `/etc/hosts` entries for the same hostname is non-standard and may confuse some tooling. In practice, k3s handles it correctly.
- `/etc/hosts` changes are local to each node. There is no central synchronization; if `blockinfile` blocks get manually edited or removed, re-run the playbook to restore.

---

## Alternatives considered


| Alternative                             | Why rejected                                                              |
| --------------------------------------- | ------------------------------------------------------------------------- |
| Pi-hole DNS only                        | Go DNS resolver bypasses NSS; backup nameserver causes NXDOMAIN           |
| Remove backup nameserver in resolv.conf | Fragile — NetworkManager may re-add it; doesn't fix Pi-hole downtime      |
| keepalived VIP                          | Correct long-term solution but adds complexity; out of scope for now      |
| kube-vip                                | Requires additional in-cluster component; more appropriate for production |
| Static IPs in inventory                 | IPs are DHCP-assigned; runtime facts are more reliable                    |
| Embed IPs in Pi-hole config             | Still single point of failure for DNS infrastructure                      |


---

## Usage

```bash
# Apply to all cluster nodes
ansible-playbook hosts.yml

# Test on a single node first (server facts are still gathered)
ansible-playbook hosts.yml --limit mou-pi5

# Verify entries are correct
ansible all -i inventory/hosts.yml -b -a 'grep cluster.oue.home /etc/hosts'
```

