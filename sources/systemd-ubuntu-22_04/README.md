# Image of Ubuntu 22.04 with systemd entry

## Manual launch

```bash
cont_name='test-container'
/usr/bin/env podman run --name "${cont_name}" -d \
host.tld/registry/path/ubuntu-systemd-22_04:latest
count=7
while ! /usr/bin/env podman exec "${cont_name}" systemctl status; do
  echo "waiting container ready, left [$count] tries"
  count=$((count - 1))
  if [[ $count -le 0 ]]; then
    echo 'container failed'
    exit 1
  fi
  sleep 1
done
if [[ $count -gt 0 ]]; then
  echo 'container ready'
fi
```

## Molecule configuration

`molecule.yml`:

```yaml
---
dependency:
  name: galaxy
driver:
  name: podman
platforms:
  - name: "tests-container"
    image: "host.tld/registry/path/ubuntu-systemd-20_04:latest"
provisioner:
  name: ansible
  env:
    ANSIBLE_VERBOSITY: 1
  inventory:
    links:
      group_vars: "group_vars"
  playbooks:
    create: create.yaml
    prepare: prepare.yaml
    converge: converge.yaml
    destroy: destroy.yaml
  config_options:
    defaults:
      remote_tmp: /tmp
      jinja2_extensions: jinja2.ext.do
verifier:
  name: ansible
scenario:
  create_sequence:
    - dependency
    - create
```
