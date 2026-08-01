#!/usr/bin/env bash
set -ueo pipefail
deb_link='http://deb.debian.org' # DevSkim: ignore DS137138
cat <<EOD >/etc/apt/sources.list.d/debian.sources
Types: deb
URIs: ${deb_link}/debian
Suites: trixie trixie-updates
Components: main contrib non-free
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp

Types: deb
URIs: ${deb_link}/debian-security
Suites: trixie-security
Components: main contrib non-free
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
EOD
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends podman netavark passt uidmap
