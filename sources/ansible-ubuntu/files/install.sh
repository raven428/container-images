#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND='noninteractive'
apt-get update
find_package() {
  apt-cache search --names-only "$1" 2>/dev/null |
    awk '{printf "%s ", $1}'
}
[[ -e /files/podman.sh ]] && /files/podman.sh
source /etc/os-release
add_pkg=''
[[ "${ID}" = 'ubuntu' && "${VERSION_ID%%.*}" -ge 24 ]] && add_pkg='systemd-resolved'
# shellcheck disable=2046
apt-get install -y --no-install-recommends bash sudo ssh-client apt-utils xz-utils less \
  ca-certificates rsync ${add_pkg} \
  $(find_package '^libreadline[_\.0-9\-]+$') \
  $(find_package '^libsqlite[_\.0-9\-]+$') \
  $(find_package '^libbz[_\.0-9\-]+$') \
  $(find_package '^zlib[\.0-9\-]+[a-z]$') \
  $(find_package '^libssl[0-9]') \
  $(find_package '^libffi[0-9]+$') \
  $(find_package '^liblzma[0-9]+$')
