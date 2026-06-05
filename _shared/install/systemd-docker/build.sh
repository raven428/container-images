#!/usr/bin/env bash
# cspell:ignore nodoc noinsttest buildpackage devscripts fakeroot debhelper
# Builder stage: configure apt, install build deps, patch and build systemd.
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
S2D='/files/shared/install/systemd-docker'
"${S2D}/apt-sources.sh" with-src
apt-get update
apt-get install -y --no-install-recommends \
  build-essential dpkg-dev devscripts fakeroot debhelper
apt-get build-dep -y systemd
apt-get source systemd
cd /systemd-*
for d in "${S2D}/patches" /files/patches; do
  [[ -d "${d}" ]] || continue
  for p in "${d}"/*.patch; do
    [[ -f "${p}" ]] && patch -p1 <"${p}"
  done
done
DEB_BUILD_OPTIONS='nocheck nodoc' \
  DEB_BUILD_PROFILES='nocheck noinsttest nodoc' \
  dpkg-buildpackage -b -uc -us -j"$(nproc)"
mv /libsystemd-shared_*.deb /tmp/
