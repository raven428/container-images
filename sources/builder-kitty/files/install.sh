#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential mingw-w64 ca-certificates curl locales
apt-get clean
rm -rf /var/lib/apt/lists/*
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen
mkdir -p /sources /builds /run /tmp
rm -Rf /usr/share/doc /usr/share/man /files
