#!/usr/bin/env bash
# cspell:ignore catatonit
set -ueo pipefail
# Installs and configures rootless podman for the "node" user (uid 1000),
# mirroring sources/vibeco-ubuntu-24_04 but without the sysadmin toolbelt.
# Expects /tmp/podman.sh (the alvistack apt installer) staged alongside.
apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends fuse-overlayfs slirp4netns uidmap podman \
  libcap2-bin netavark passt crun runc catatonit
# newuidmap/newgidmap: capabilities instead of setuid (matches podman/stable)
chmod 0755 /usr/bin/newuidmap /usr/bin/newgidmap
setcap cap_setuid+ep /usr/bin/newuidmap
setcap cap_setgid+ep /usr/bin/newgidmap
# subuid/subgid: range visible inside outer container (uid 1..65536),
# with a hole at 1000 (node's own uid)
printf 'root:888:98998\nnode:100000:899999\n' | tee /etc/subuid /etc/subgid
# system-wide containers.conf for nested podman
mkdir -vp /etc/containers
cat <<'EOF' >/etc/containers/containers.conf
# [containers]
# netns = "host"
# userns = "host"
# ipcns = "host"
# utsns = "host"
# cgroupns = "host"
# cgroups = "disabled"
# log_driver = "k8s-file"

# [engine]
# cgroup_manager = "cgroupfs"
# events_logger = "file"
# runtime = "crun"
EOF
chmod 644 /etc/containers/containers.conf
# storage.conf: enable fuse-overlayfs and shared image store
cat <<'EOF' >/etc/containers/storage.conf
[storage]
driver = "overlay"
graphroot = "/var/lib/containers/storage"
runroot = "/run/containers/storage"
[storage.options]
additionalimagestores = [
  "/var/lib/shared",
]
[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
mountopt = "nodev,fsync=0"
EOF
# shared image store dirs
mkdir -vp \
  /var/lib/shared/overlay-images \
  /var/lib/shared/overlay-layers \
  /var/lib/shared/vfs-images \
  /var/lib/shared/vfs-layers
touch \
  /var/lib/shared/overlay-images/images.lock \
  /var/lib/shared/overlay-layers/layers.lock \
  /var/lib/shared/vfs-images/images.lock \
  /var/lib/shared/vfs-layers/layers.lock
# per-user containers config for node
mkdir -vp /home/node/.config/containers /srv/data/podman/node
cat <<'EOF' >/home/node/.config/containers/containers.conf
[containers]
volumes = [
  "/proc:/proc",
]
default_sysctls = []
EOF
cat <<'EOF' >/home/node/.config/containers/storage.conf
[storage]
driver = "overlay"
graphRoot = "/srv/data/podman/node"
EOF
chown -R node:node /home/node /srv/data/podman/node
# cleanup
rm -rf /var/lib/apt/lists/*
