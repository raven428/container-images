#!/usr/bin/env bash
set -ueo pipefail
apt-get update -y
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y podman golang-github-containers-common golang-github-containers-image \
  aardvark-dns netavark containernetworking-plugins || true
apt-get install -y curl
# shellcheck disable=1091
source '/etc/os-release'
case "${ID}" in
'ubuntu')
  ID='xUbuntu'
  ;;
'debian')
  ID='Debian'
  ;;
esac
mkdir -vp /etc/apt/sources.list.d
curl -fsSLm 11 "https://downloadcontent.opensuse.org/repositories/home:/alvistack\
/${ID}_${VERSION_ID}/Release.key" -o /etc/apt/keyrings/alvistack.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/alvistack.asc] \
https://downloadcontent.opensuse.org/repositories/home:/alvistack/${ID}_${VERSION_ID} \
/" >/etc/apt/sources.list.d/alvistack.list
apt-get update -y
apt-get install -y --no-install-recommends podman podman-netavark passt uidmap
# In alvistack repo podman 6.0 buildah now pulls containers-storage as a hard
# dependency, which ships /usr/share/containers/storage.conf with an active
# graphroot=/var/lib/containers/storage applied to rootless too. That breaks
# unprivileged builds with "mkdir /var/lib/containers/storage: permission
# denied". Shadow the shipped config with a minimal /etc override so rootless
# falls back to $HOME/.local/share/containers/storage and rootful keeps system
# defaults. Existing custom configs are preserved.
[[ ! -e /etc/containers/storage.conf ]] && cat <<'EOF' >/etc/containers/storage.conf
[storage]
driver = "overlay"
EOF
