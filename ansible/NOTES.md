# NOTES

## Get details on cluster

```shell
# Check the age of the most recent debug if it is within the hour don't update
file=ansible-debug/hostvars.json
# uncomment to force update
rm "${file}"
if [[ "$(stat -f "%m" "${file}" 2>/dev/null)" -lt "$(( $(date +%s) - 3600 ))" ]]; then
  ansible-playbook debug-vars.yml
fi
cat "${file}" \
| jq -rnc 'inputs | .[].ansible_facts |
{
    hostname
  , board_vendor
  , board_version
  , distribution
  , distribution_version
  , architecture
  , ip:.default_ipv4.address
  , memtotal_mb
  , processor_vcpus
  , proc_type:.processor[2]
  , devices: ([
    .mounts[] | select([(.device|test("^/dev/sd")), (.mount|test("^/boot")|not), (.size_total//0 > 0)]|all) |
    "\(.mount) (\(.size_total/1024/1024/1024 | floor*100/100)GB)"
  ] | join("; "))
}
' \
| jq -rnc '[inputs] |
  (.[0] | keys | @csv) ,(.[] | to_entries | map(.value) | @csv)  
' \
| tee cluster-nodes.csv

open cluster-nodes.csv
```

```shell
alias abspath='stat -f "%R" '
abspath ansible-debug/hostvars.json
```