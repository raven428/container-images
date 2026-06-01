# Image of Debian 12 (bookworm) with systemd entry

Runs systemd 252 as PID 1 in a standard Docker container **without** any
extra flags, capabilities, or host modifications. Works on Docker hosts with
cgroup v2 (Linux ≥ 5.2).

The image contains a binary patch of `libsystemd-shared-252.so` that makes
`cg_create` and `cg_attach` silently succeed when `/sys/fs/cgroup` is
read-only (the default for unprivileged Docker containers). Systemd still
manages services normally; it just cannot actually track processes in cgroups.

## Manual launch

```bash
cont_name='test-container'
/usr/bin/env docker run --name "${cont_name}" -d \
  --tmpfs /run --tmpfs /run/lock \
  host.tld/registry/path/debian-systemd-12:latest
count=7
while ! /usr/bin/env docker exec "${cont_name}" systemctl status; do
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
  name: docker
platforms:
  - name: "tests-container"
    image: "host.tld/registry/path/debian-systemd-12:latest"
    tmpfs:
      - /run
      - /run/lock
    command: /lib/systemd/systemd
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
