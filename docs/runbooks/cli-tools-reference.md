# CLI tools reference — k3s homelab

Quick reference for CLI tools used to troubleshoot and manage the k3s homelab cluster. Grouped by area of concern.

---

## systemd / service management

```bash
# Service status
systemctl status k3s
systemctl status k3s-agent

# Start / stop / restart
systemctl start k3s-agent
systemctl stop k3s-agent
systemctl restart k3s-agent

# Enable / disable autostart
systemctl enable k3s-agent
systemctl disable k3s-agent

# Check if a service is enabled
systemctl is-enabled k3s-agent

# Show service unit file
systemctl cat k3s-agent

# Reload systemd after editing unit files
systemctl daemon-reload
```

---

## journalctl — log inspection

```bash
# Last 50 lines, no pager
journalctl -u k3s -n 50 --no-pager
journalctl -u k3s-agent -n 50 --no-pager

# Follow live
journalctl -u k3s-agent -f

# Since last boot
journalctl -u k3s-agent -b --no-pager

# Since a specific time
journalctl -u k3s-agent --since "10 minutes ago" --no-pager
journalctl -u k3s-agent --since "2026-04-07 14:00:00" --no-pager

# Filter for errors only
journalctl -u k3s-agent -p err --no-pager

# Show kernel messages (useful for cgroup/memory issues on Pi)
journalctl -k -b --no-pager | grep -i cgroup
```

---

## DNS and name resolution

### nslookup

```bash
nslookup cluster.oue.home                     # uses /etc/resolv.conf default
nslookup cluster.oue.home 192.168.5.163       # query specific nameserver
```

### dig

```bash
dig cluster.oue.home                          # full DNS response
dig cluster.oue.home +short                   # IPs only
dig @192.168.5.163 cluster.oue.home           # query specific nameserver
dig @192.168.5.163 cluster.oue.home +short    # IPs from specific nameserver
dig cluster.oue.home ANY                      # all record types

# Check all nameservers in resolv.conf
for ns in $(awk '/^nameserver/{print $2}' /etc/resolv.conf); do
  echo "--- nameserver $ns ---"
  dig @$ns cluster.oue.home +short
done
```

### getent — NSS-aware lookup (libc / glibc path)

```bash
getent hosts cluster.oue.home         # first IP, like gethostbyname()
getent ahosts cluster.oue.home        # all IPs with socket type
getent ahostsv4 cluster.oue.home      # IPv4 only
```

`getent` respects `nsswitch.conf` order (`files dns`), so it checks `/etc/hosts` before DNS. k3s (Go binary) does **not** use `getent` — it reads `/etc/resolv.conf` directly.

### /etc/hosts and nsswitch

```bash
grep cluster.oue.home /etc/hosts
grep hosts /etc/nsswitch.conf
cat /etc/resolv.conf
```

---

## Network connectivity

### curl — HTTP/HTTPS tests

```bash
# Test k3s API endpoint (accept self-signed cert)
curl -k https://cluster.oue.home:6443/cacerts
curl -k https://192.168.5.151:6443/cacerts     # test by IP if DNS suspect

# Test with token auth
TOKEN=$(cat /etc/systemd/system/k3s.service.env | grep K3S_TOKEN | cut -d= -f2-)
curl -k -H "Authorization: Bearer $TOKEN" \
  https://cluster.oue.home:6443/v1-k3s/client-ca.crt

# Verbose — shows TLS handshake details and cert chain
curl -kv https://cluster.oue.home:6443/cacerts 2>&1 | head -40

# Measure timing (useful for DNS TTL=0 issues)
curl -k -w "@-" -o /dev/null -s https://cluster.oue.home:6443/cacerts <<'EOF'
  dns_resolution:  %{time_namelookup}s
  connect:         %{time_connect}s
  tls_handshake:   %{time_appconnect}s
  total:           %{time_total}s
EOF
```

### nc (netcat) — port reachability

```bash
nc -zv cluster.oue.home 6443         # test TCP port (verbose)
nc -zv 192.168.5.151 6443            # by IP
nc -zv -w 3 cluster.oue.home 6443    # 3-second timeout
```

### ping

```bash
ping -c 3 cluster.oue.home
ping -c 3 mou-mini1.oue.home
```

### ip / ss — local network and socket state

```bash
ip addr show                          # all interfaces and IPs
ip addr show eth0                     # specific interface
ip route                              # routing table
ss -tlnp                              # listening TCP sockets with process
ss -tlnp | grep 6443                  # check API port
ss -tlnp | grep 6444                  # check k3s local proxy
```

---

## NetworkManager — nmcli

```bash
# Show all connections
nmcli con show

# Show active connections
nmcli con show --active

# Show connection details (DNS, gateway, IP)
nmcli con show <connection-name>
nmcli dev show eth0

# Show only DNS for a connection
nmcli con show <connection-name> | grep -i dns

# Set DNS servers permanently (replace auto-assigned)
nmcli con mod <connection-name> ipv4.dns "192.168.5.163"
nmcli con mod <connection-name> ipv4.ignore-auto-dns yes
nmcli con up <connection-name>

# Remove override, revert to auto DNS
nmcli con mod <connection-name> ipv4.dns ""
nmcli con mod <connection-name> ipv4.ignore-auto-dns no
nmcli con up <connection-name>

# Apply changes without disconnecting
nmcli con reload
```

---

## kubectl — cluster inspection

```bash
# Node status
kubectl get nodes
kubectl get nodes -o wide               # includes IPs and kernel version

# Watch nodes until Ready
kubectl get nodes -w

# Describe a node (events, conditions, resources)
kubectl describe node mou-pi5

# Delete a stale node record before re-joining
kubectl delete node mou-pi5

# Check all pods (useful after node rejoins)
kubectl get pods -A
kubectl get pods -A -o wide             # shows which node each pod runs on

# Events across the cluster
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check API server
kubectl cluster-info
```

---

## k3s binary

```bash
# Check config/requirements (cgroups, kernel modules)
k3s check-config

# Run agent manually with debug output (stop service first)
systemctl stop k3s-agent
k3s agent \
  --server https://cluster.oue.home:6443 \
  --token <token> \
  --debug 2>&1 | head -30

# Token validation — get cluster token
cat /var/lib/rancher/k3s/server/token

# Get service kubeconfig
cat /etc/rancher/k3s/k3s.yaml
```

---

## Raspberry Pi specific

```bash
# Check cgroup kernel cmdline args
cat /proc/cmdline
grep -o 'cgroup[^ ]*' /proc/cmdline

# Check active cgroup controllers
cat /sys/fs/cgroup/cgroup.controllers

# Edit boot config
cat /boot/firmware/cmdline.txt          # Raspberry Pi OS (Bookworm+)
cat /boot/cmdline.txt                   # older Raspberry Pi OS

# Check available memory
free -h
vcgencmd measure_temp                   # CPU temp
vcgencmd get_throttled                  # 0x0 = no throttle; non-zero = power issue

# Reboot (from controller)
ansible <host> -i inventory/hosts.yml -b -a 'reboot' --async 0 --poll 0
```

---

## Ansible — ad-hoc and playbook commands

### Running commands on remote hosts

```bash
# Run a shell command on a group
ansible server -i inventory/hosts.yml -b -a 'kubectl get nodes'
ansible agent  -i inventory/hosts.yml -b -a 'systemctl status k3s-agent'
ansible all    -i inventory/hosts.yml -b -a 'cat /etc/resolv.conf'

# Run a module
ansible mou-pi5 -i inventory/hosts.yml -b -m setup -a 'filter=ansible_default_ipv4'
ansible mou-pi5 -i inventory/hosts.yml -b -m wait_for_connection

# Gather facts (check IP of each server)
ansible server -i inventory/hosts.yml -b -m setup \
  -a 'filter=ansible_default_ipv4' 2>/dev/null | grep address
```

### Playbooks

```bash
# Full site (all nodes)
ansible-playbook site.yml

# Limit to specific hosts or groups
ansible-playbook site.yml --limit 'mou-mini1,mou-pi5'
ansible-playbook site.yml --limit server
ansible-playbook site.yml --limit agent

# Tags
ansible-playbook site.yml --tags kubeconfig
ansible-playbook site.yml --tags k3s_install

# Dry run
ansible-playbook site.yml --check --diff

# Verbose (increase -v for more detail, up to -vvvv)
ansible-playbook site.yml -v
ansible-playbook site.yml -vvv

# Reset (uninstall k3s)
ansible-playbook reset.yml --limit agent
ansible-playbook reset.yml                    # all nodes

# Hosts playbook (manage /etc/hosts on all nodes)
ansible-playbook hosts.yml
ansible-playbook hosts.yml --limit mou-pi5   # test on one node first
```

### Inventory inspection

```bash
# List all hosts and variables
ansible-inventory -i inventory/hosts.yml --list
ansible-inventory -i inventory/hosts.yml --host mou-pi5

# Check effective variable values
ansible -i inventory/hosts.yml all -m debug -a 'var=api_endpoint'
ansible -i inventory/hosts.yml all -m debug -a 'var=k3s_version'
ansible -i inventory/hosts.yml all -m debug -a 'var=token'
```

### Config inspection

```bash
# Show non-default config
ansible-config dump --only-changed

# List all config options with sources
ansible-config list | grep -A5 collections_path

# Verify collection search path is correct
ansible-config dump | grep collection
```

---

## Git

```bash
# Status across both repos
git -C ~/Projects/k8/homelab status
git -C ~/Projects/k8/k3s-ansible status

# See what changed in k3s-ansible
git -C ~/Projects/k8/k3s-ansible diff

# Log with branch context
git -C ~/Projects/k8/k3s-ansible log --oneline -10
```

---

## References

- [k3s-agent-cluster-connectivity-troubleshooting runbook](k3s-agent-cluster-connectivity-troubleshooting.md)
- [k3s-control-plane-reset runbook](k3s-control-plane-reset.md)
- [ansible-variable-scopes-and-playbook-relativity runbook](ansible-variable-scopes-and-playbook-relativity.md)
- [ansible-local-collection-development runbook](ansible-local-collection-development.md)
- [DDD 004 — /etc/hosts for HA cluster endpoint](../design_decision_documents/004-etc-hosts-for-ha-cluster-endpoint.md)
