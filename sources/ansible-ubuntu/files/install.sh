#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND='noninteractive'
apt-get update
find_package() {
  apt-cache search --names-only "$1" 2>/dev/null |
    awk '{print $1}'
}
/files/podman.sh
apt-get install -y --no-install-recommends bash sudo ssh-client apt-utils xz-utils less \
  ca-certificates rsync systemd-resolved \
  "$(find_package '^libreadline[_\.0-9\-]+$')" \
  "$(find_package '^libsqlite[_\.0-9\-]+$')" \
  "$(find_package '^libbz[_\.0-9\-]+$')" \
  "$(find_package '^zlib[\.0-9\-]+[a-z]$')" \
  "$(find_package '^libssl[0-9]')" \
  "$(find_package '^libffi[0-9]+$')" \
  "$(find_package '^liblzma[0-9]+$')"
