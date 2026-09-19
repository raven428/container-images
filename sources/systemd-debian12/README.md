# Image of Debian 12 (bookworm) with systemd entry

Runs stock systemd 252 as PID 1 in a rootless podman container without any extra flags,
capabilities, or host modifications.

No patched systemd is shipped. The image entry point is `/sbin/init`, which makes podman
enable its systemd mode: it mounts `/sys/fs/cgroup` read-write and puts tmpfs on `/run`,
`/run/lock`, `/tmp` and `/var/log/journal`. That entry point is a small wrapper that
streams the journal to stdout, so the whole systemd log is visible via `podman logs`, and
then executes systemd itself.

## Manual launch

```bash
cont_name='test-container'
/usr/bin/env podman run --name "${cont_name}" -d \
  host.tld/registry/path/systemd-debian12:latest
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
    image: "host.tld/registry/path/systemd-debian12:latest"
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
