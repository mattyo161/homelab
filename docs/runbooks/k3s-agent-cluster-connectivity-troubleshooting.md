# Runbook: k3s agent cluster connectivity troubleshooting

Use when a k3s agent (or server joiner) is stuck with repeated errors like:

```
Failed to validate connection to cluster at https://cluster.oue.home:6443:
failed to get CA certs: Get "https://127.0.0.1:6444/cacerts": read: connection reset by peer
```

or

```
dial tcp: lookup cluster.oue.home: no such host
```

---

## Quick orientation

The k3s agent uses an **internal load balancer proxy** on `127.0.0.1:6444`. All agent traffic goes through this proxy first. The proxy dials the real cluster endpoint (`cluster.oue.home:6443`). If the proxy can't reach the cluster, it resets incoming connections — producing the misleading `connection reset by peer` on `127.0.0.1:6444`.

**The `127.0.0.1:6444` error is always a symptom, not the root cause.** Always look one level deeper.

---

## Step 1 — Enable debug logging

Run k3s agent manually with `--debug` to see the real error:

```bash
# Stop the service first
systemctl stop k3s-agent

# Run manually — first 20 lines usually contain the root cause
k3s agent \
  --server https://cluster.oue.home:6443 \
  --token <token> \
  --debug 2>&1 | head -20
```

Key lines to look for:

| Pattern | Meaning |
|---------|---------|
| `lookup cluster.oue.home: no such host` | DNS resolution failure |
| `connection refused` | Server port not open / firewall |
| `certificate signed by unknown authority` | CA mismatch / stale certs |
| `not authorized` / `401` | Token rejected by cluster |
| `all servers failed` | Load balancer can't reach any server IP |

---

## Step 2 — DNS resolution checks

### Check what the system resolver returns

```bash
# Standard DNS lookup (uses /etc/resolv.conf + NSS)
nslookup cluster.oue.home
dig cluster.oue.home

# NSS-aware lookup (what getaddrinfo/libc uses)
getent hosts cluster.oue.home
getent ahosts cluster.oue.home   # shows all IPs with socket types
```

### Check what Go's DNS resolver sees

k3s uses Go's **pure DNS resolver** which reads `/etc/resolv.conf` directly and bypasses NSS. Test it by resolving via the nameserver directly:

```bash
# Query the nameserver Go would use (from /etc/resolv.conf)
dig @$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf) cluster.oue.home
```

### One-liner Go DNS test (no extra tools)

```bash
# Check all nameservers in resolv.conf — Go may fall through to whichever responds first
for ns in $(awk '/^nameserver/{print $2}' /etc/resolv.conf); do
  echo "--- nameserver $ns ---"
  dig @$ns cluster.oue.home +short
done
```

If one nameserver returns IPs and another returns nothing (e.g. your router doesn't know about `cluster.oue.home`), Go may fall through to the failing nameserver.

### Check /etc/hosts entries

```bash
grep cluster.oue.home /etc/hosts
```

Expected output (one line per server):

```
192.168.5.151 cluster.oue.home
192.168.5.165 cluster.oue.home
192.168.5.166 cluster.oue.home
```

If missing, run the hosts playbook:

```bash
ansible-playbook hosts.yml --limit <node>
```

### Check nsswitch resolution order

```bash
grep hosts /etc/nsswitch.conf
```

Should be `files dns` or `files mdns4_minimal [NOTFOUND=return] dns`.

**Debian 13 trixie gotcha:** `mdns4_minimal [NOTFOUND=return]` blocks DNS fallback for non-`.local` names in some resolution contexts. If `/etc/hosts` entries are present this is a non-issue, but if you need DNS-only resolution:

```bash
sed -i 's/mdns4_minimal \[NOTFOUND=return\] //' /etc/nsswitch.conf
```

---

## Step 3 — Network connectivity checks

### Can the node reach the cluster API?

```bash
# Direct curl to cluster endpoint (bypasses k3s proxy)
curl -k https://cluster.oue.home:6443/cacerts
curl -k https://192.168.5.151:6443/cacerts   # test by IP if DNS suspect

# Port reachability
nc -zv cluster.oue.home 6443
nc -zv 192.168.5.151 6443
```

A successful `/cacerts` response returns a PEM certificate block. `connection refused` or timeout means the server is unreachable from this node.

### Test token authentication directly

```bash
TOKEN=$(cat /etc/systemd/system/k3s-agent.service.env | cut -d= -f2-)
curl -k -H "Authorization: Bearer $TOKEN" \
  https://cluster.oue.home:6443/v1-k3s/client-ca.crt
```

- Returns certificate content → token valid
- Returns `401 Unauthorized` → token rejected (wrong token or CA hash mismatch)

### Check local proxy status

```bash
ss -tlnp | grep 6444
# Should show k3s-agent listening on 127.0.0.1:6444 when agent is running
```

---

## Step 4 — Token and certificate checks

### Compare token between nodes

```bash
# On controller — compare env file tokens
ansible server,agent -i inventory/hosts.yml -b \
  -a 'cat /etc/systemd/system/k3s-agent.service.env' 2>/dev/null

# Get current cluster token from first server
ansible mou-mini1 -i inventory/hosts.yml -b \
  -a 'cat /var/lib/rancher/k3s/server/token'
```

The token in `k3s-agent.service.env` (`K3S_TOKEN=`) must be compatible with what the cluster was bootstrapped with. The short form (`base64string==`) and the full form (`K10<cahash>::server:<secret>`) are both valid if the CA hash matches the cluster.

### Stale agent data directory

If the agent previously joined a **different** cluster, stale CA certs in `/var/lib/rancher/k3s/agent/` cause CA validation failures on the new cluster.

```bash
# Check for stale agent data
ls /var/lib/rancher/k3s/agent/

# Clear it (node must be reset or k3s-agent stopped)
systemctl stop k3s-agent
rm -rf /var/lib/rancher/k3s/agent
systemctl start k3s-agent
```

---

## Step 5 — resolv.conf and NetworkManager

### Check current DNS config

```bash
cat /etc/resolv.conf
ls -la /etc/resolv.conf    # check if symlink to systemd-resolved stub

# If managed by NetworkManager
nmcli dev show | grep DNS
nmcli con show <connection-name> | grep dns
```

### Remove a problematic backup nameserver permanently

If your router (`192.168.1.1`) is listed as a fallback but doesn't know about local DNS entries like `cluster.oue.home`, Go may fall through to it and get `NXDOMAIN`.

```bash
# Temporary (will be overwritten by NetworkManager on reconnect)
sed -i '/^nameserver 192.168.1.1/d' /etc/resolv.conf

# Permanent via NetworkManager
nmcli con mod <connection-name> ipv4.dns "192.168.5.163"
nmcli con mod <connection-name> ipv4.ignore-auto-dns yes
nmcli con up <connection-name>
```

The `/etc/hosts` approach (see `hosts.yml` playbook) is generally better than removing the backup nameserver — it ensures `cluster.oue.home` resolves locally without DNS at all.

---

## Step 6 — Service and systemd checks

```bash
# Service status and last log lines
systemctl status k3s-agent

# Follow logs live
journalctl -u k3s-agent -f

# Last N lines
journalctl -u k3s-agent -n 50 --no-pager

# Since last boot
journalctl -u k3s-agent -b --no-pager | tail -50

# From controller via Ansible
ansible mou-pi5 -i inventory/hosts.yml -b \
  -a 'journalctl -u k3s-agent -n 50 --no-pager'
```

---

## Step 7 — Raspberry Pi specific

### cgroups not active after reset

After `k3s-uninstall.sh` runs (via reset playbook), the cgroup subsystem may be in a partially torn-down state. Even if `cmdline.txt` has the correct cgroup entries, a reboot is required before k3s can start cleanly.

```bash
# Verify cgroups are active
cat /proc/cmdline | grep -o 'cgroup[^ ]*'
# Should include: cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory

cat /sys/fs/cgroup/cgroup.controllers
# Should include: memory

# Full k3s config check
k3s check-config 2>&1 | grep -E 'cgroup|FAIL|warn'
```

If cgroups are in cmdline.txt but not in `/proc/cmdline`, reboot the pi before re-running the site playbook.

### Reboot and wait from controller

```bash
ansible mou-pi5 -i inventory/hosts.yml -b -a 'reboot' --async 0 --poll 0
sleep 30
ansible mou-pi5 -i inventory/hosts.yml -m wait_for_connection
```

---

## Step 8 — Cluster-side checks (stale node records)

After resetting a node, the cluster API still shows the old node record as `NotReady`. k3s re-registers on join but the old record may conflict.

```bash
# Check for stale NotReady nodes
kubectl get nodes

# Delete stale record before rejoining
kubectl delete node mou-pi5

# Then re-run site playbook
ansible-playbook site.yml --limit 'mou-mini1,mou-pi5'
```

---

## Common error → cause → fix table

| Error | Root cause | Fix |
|-------|-----------|-----|
| `lookup cluster.oue.home: no such host` | Go DNS can't resolve hostname | Add to `/etc/hosts` via `hosts.yml` playbook |
| `lookup ... no such host` with `/etc/hosts` present | Backup nameserver (`192.168.1.1`) returns NXDOMAIN before `/etc/hosts` is checked | `/etc/hosts` takes priority over DNS; check `nsswitch.conf` has `files` first |
| `connection reset by peer` on `127.0.0.1:6444` | Local proxy can't reach server — DNS or network failure | Always look at debug logs for the underlying dial error |
| `not authorized` / `401` on `/v1-k3s/client-ca.crt` | Token rejected by cluster | Verify token matches `server/token` on mou-mini1 |
| CA validation warning + join fails | Short token used, cluster CA changed since last join | Clear `/var/lib/rancher/k3s/agent/` and restart |
| Agent joins but wrong k3s version | Agents were installed before version bump and never upgraded | Run `ansible-playbook site.yml --limit agent` |
| Node shows `NotReady` after reset+reinstall | Stale record in cluster API | `kubectl delete node <name>` then rejoin |
| k3s fails to start on Pi after reset | cgroups not reinitialized after `k3s-killall.sh` | Reboot Pi before reinstalling |

---

## References

- [DDD 004 — /etc/hosts for HA cluster endpoint](../design_decision_documents/004-etc-hosts-for-ha-cluster-endpoint.md)
- [k3s-control-plane-reset runbook](k3s-control-plane-reset.md)
- [ansible-variable-scopes-and-playbook-relativity runbook](ansible-variable-scopes-and-playbook-relativity.md)
- [NOTES.md — --limit and HA server joins](../NOTES.md)
