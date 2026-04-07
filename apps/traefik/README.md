# Traefik

## Disabling the built-in k3s Traefik before installing this one

k3s installs Traefik v2 by default via a `HelmChart` CR. Before deploying the Helm-managed Traefik v3, you must disable the built-in one to avoid port conflicts.

Add the following to `ansible/inventory/group_vars/k3s_cluster/main.yml`:

```yaml
k3s_server_config:
  disable:
    - traefik
```

Then re-run the site playbook to apply:

```bash
ansible-playbook -i inventory/hosts.yml site.yml --tags k3s_install
```

Verify the built-in Traefik is gone:

```bash
kubectl get pods -n kube-system | grep traefik
# Should return nothing
```

Then run apps.yml normally.

## Dashboard access

The Traefik dashboard is exposed at `https://traefik.oue.home/dashboard/` (note the trailing slash). It requires no auth in the current config — add BasicAuth middleware if you want to protect it.
