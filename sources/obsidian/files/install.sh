#!/usr/bin/env bash
# cspell:ignore obsidian novnc websockify xvfb x11vnc fluxbox nologin libasound openrc
# cspell:ignore procps mountkernfs
set -xueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends xvfb x11vnc novnc websockify openrc \
  fluxbox dbus-x11 wget ca-certificates libasound2t64
_obsidian_ver='1.6.3'
_obsidian_url="https://github.com/obsidianmd/obsidian-releases/releases/download/\
v${_obsidian_ver}/obsidian_${_obsidian_ver}_amd64.deb"
_deb='/tmp/obsidian.deb'
wget -qO "${_deb}" "${_obsidian_url}"
dpkg -i "${_deb}" || apt-get install -fy --no-install-recommends
rm -f "${_deb}"
useradd -m -s /bin/bash obsidian
install -d -m 755 /vault /config
chown obsidian:obsidian /vault /config
# install openrc service scripts
for _svc in xvfb fluxbox x11vnc novnc obsidian; do
  install -m 755 "/files/init.d/${_svc}" "/etc/init.d/${_svc}"
  rc-update add "${_svc}" default
done
install -m 755 /files/entrypoint.sh /entrypoint.sh
# configure openrc for container use (no cgroups, no hardware)
sed -i 's/#rc_sys=""/rc_sys="docker"/' /etc/rc.conf
# remove procps init script that depends on non-existent mountkernfs
rm -f /etc/init.d/procps
# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache /files
