#!/usr/bin/env bash
# cspell:ignore obsidian novnc websockify xvfb x11vnc fluxbox nologin libasound
set -xueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends xvfb x11vnc novnc websockify supervisor \
  fluxbox dbus-x11 wget ca-certificates libasound2t64
_obsidian_ver='1.6.3'
_obsidian_url="https://github.com/obsidianmd/obsidian-releases/releases/download/\
v${_obsidian_ver}/obsidian_${_obsidian_ver}_amd64.deb"
_deb='/tmp/obsidian.deb'
wget -qO "${_deb}" "${_obsidian_url}"
dpkg -i "${_deb}" || apt-get install -fy --no-install-recommends
rm -f "${_deb}"
useradd -m -s /bin/bash obsidian
mkdir -p /var/run/supervisor
install -d -m 755 /vault /config
chown obsidian:obsidian /vault /config
install -m 644 /files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
install -m 755 /files/xvfb-start.sh /usr/local/bin/xvfb-start.sh
install -m 755 /files/entrypoint.sh /entrypoint.sh
# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache /files
