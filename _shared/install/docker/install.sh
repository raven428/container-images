#!/usr/bin/env bash
set -xueo pipefail

# generic packages
apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends systemd iproute2 python3-apt aptitude less \
  xz-utils python3-psutil python3-zstd python3-lz4 secure-delete openssh-server curl \
  ca-certificates xz-utils

# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
# shellcheck disable=1091
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(source /etc/os-release && echo "$VERSION_CODENAME") stable" |
  tee /etc/apt/sources.list.d/docker.list >/dev/null
apt-get update
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# image configuration
update-ca-certificates
systemctl enable systemd-resolved docker
systemctl disable systemd-networkd ssh

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
rm -f /lib/systemd/system/systemd*udev* rm -f /lib/systemd/system/getty.target

# cleanup
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
