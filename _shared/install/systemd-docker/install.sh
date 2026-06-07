#!/usr/bin/env bash
# Runtime stage: configure apt, install packages, apply systemd tweaks.
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
S2D='/files/shared/install/systemd-docker'
"${S2D}/apt-sources.sh"
apt-get update
apt-get install -y --no-install-recommends systemd bash less ca-certificates iproute2 \
  curl openssh-server
systemctl enable ssh
apt-get clean
rm -rf /usr/share/doc /usr/share/man /var/lib/apt/lists/*
dpkg -i /tmp/libsystemd-shared_*.deb
rm -f /tmp/libsystemd-shared_*.deb
systemd-machine-id-setup
# Mask units that require kernel access unavailable in unprivileged Docker
xargs -a "${S2D}/masked-units.list" systemctl mask
mkdir -p /etc/systemd/journald.conf.d /etc/systemd/system.conf.d
cp "${S2D}/journald.conf" /etc/systemd/journald.conf.d/10-docker.conf
cp "${S2D}/system.conf" /etc/systemd/system.conf.d/10-docker.conf
cp "${S2D}/entrypoint.sh" /entrypoint.sh
chmod 755 /entrypoint.sh

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
