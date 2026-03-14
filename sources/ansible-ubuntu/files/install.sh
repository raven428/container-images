#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND='noninteractive'
apt-get update
# shellcheck disable=SC1091
source /etc/os-release
# shellcheck disable=SC1091
source /files/shared/install/ansible/common.sh
[[ -e /files/shared/podman.sh ]] && /files/shared/podman.sh
add_pkg=''
[[ "${ID}" = 'ubuntu' && "${VERSION_ID%%.*}" -ge 24 ]] && add_pkg='systemd-resolved'
# shellcheck disable=2046
apt-get install -y --no-install-recommends bash sudo ssh-client apt-utils xz-utils less \
  ca-certificates rsync ${add_pkg} \
  $(python_runtime_packages)
