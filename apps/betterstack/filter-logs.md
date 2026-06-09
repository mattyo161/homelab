# Filter logs in betterstack

Add the following transform to: https://telemetry.betterstack.com/team/t554697/sources/2504947/transformation

```json
if .kubernetes.pod_namespace == "longhorn-system" {
  if .kubernetes.container_name == "longhorn-manager" || .kubernetes.container_name == "instance-manager" {
    .message_parsed = parse_logfmt(.message) ?? {}
    if .message_parsed.level == "warning" || .message_parsed.level == "info" {
        del(.)
    }
  }
}
```