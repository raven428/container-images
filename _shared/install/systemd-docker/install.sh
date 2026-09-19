#!/usr/bin/env bash
# cspell:ignore: sysv
# Runtime stage: configure apt, install packages, apply systemd tweaks.
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
S2D='/files/shared/install/systemd-docker'
# Base images already ship the right suites and components, so only Ubuntu needs the
# mirror swap: CI builds run on GitHub runners hosted in Azure.
if [[ -r /etc/apt/sources.list.d/ubuntu.sources ]]; then
  sed -i 's|//archive.ubuntu.com|//azure.archive.ubuntu.com|' \
    /etc/apt/sources.list.d/ubuntu.sources
fi
apt-get update
apt-get install -y --no-install-recommends apt-utils aptitude bash ca-certificates curl \
  iproute2 less openssh-server python3 python3-apt python3-lz4 python3-psutil \
  python3-zstd sudo systemd xz-utils
systemctl enable ssh
apt-get clean
rm -rf /usr/share/doc /usr/share/man /var/lib/apt/lists/*
systemd-machine-id-setup
# Mask units that require kernel access unavailable in unprivileged Docker
xargs -a "${S2D}/masked-units.list" systemctl mask
mkdir -p /etc/systemd/journald.conf.d /etc/systemd/system.conf.d
cp "${S2D}/journald.conf" /etc/systemd/journald.conf.d/10-docker.conf
cp "${S2D}/system.conf" /etc/systemd/system.conf.d/10-docker.conf
# Podman turns on systemd mode (rw /sys/fs/cgroup, tmpfs on /run and /tmp) only when
# the container command is /sbin/init, /usr/sbin/init, /usr/local/sbin/init or any path
# whose basename is "systemd". Installing the journal wrapper as /sbin/init keeps both
# the journal streaming and the automatic systemd mode. In Debian and Ubuntu /sbin/init
# belongs to systemd-sysv, which is not installed here, so the path is free.
if [[ -e /sbin/init ]]; then
  echo 'refusing to overwrite existing /sbin/init (systemd-sysv installed?)' >&2
  exit 1
fi
cp "${S2D}/entrypoint.sh" /sbin/init
chmod 755 /sbin/init

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
