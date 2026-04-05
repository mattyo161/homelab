# bootstrap-README.md

Initial configuration items that need to be run or configured

## bootstrap-sudo.yaml

This playbook will add your user to the `/etc/sudoers.d/99_<username>` path allowing your user to sudo without having to enter a passoword or use the `-K` or `--ask-become-pass` argumenet to your ansible commands after this is run.

```shell
# test playbook on a single host
ansible-playbook bootstrap-sudo.yaml --limit <hostname> -K

# if that goes well then deploy to all of theml
ansible-playbook bootstrap-sudo.yaml -K
```

## bootstrap-user-ansible.yaml

Create a common admin user like `ansible` that restricts access to SSH key only and is added to the sudoers.d similar to the individual user entry [[#bootstrap-sudo.yaml]]. This ensures that if the user is using their own credential they will need to enter their password.

TODO: Still need to determine auditability of using this common user to be able to trace or track back to the person or process that ran the command to begin with.

```shell
# test playbook on a single host
ansible-playbook bootstrap-user-ansible.yaml --limit <hostname> -K

# if that goes well then deploy to all of theml
ansible-playbook bootstrap-user-ansible.yaml -K
```

