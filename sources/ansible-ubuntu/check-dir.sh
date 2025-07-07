#!/usr/bin/env bash
set -ueo pipefail
: "${DIR2CHECK:="."}"
: "${PATH2CONT:="/data"}"
: "${CONT_NAME:="linters-ansible-${USER}"}"
: "${ANSIBLENTRY:=""}"
: "${IMAGE_NAME:="ghcr.io/raven428/container-images/ansible-11:latest"}"
DIR2CHECK="$(readlink -f "${DIR2CHECK}")"
export ANSIBLENTRY
/usr/bin/env podman run --rm \
  -i -w "${PATH2CONT}" \
  --name="${CONT_NAME}" \
  --hostname="${CONT_NAME}" \
  -e "ANSIBLENTRY" \
  -v "${DIR2CHECK}:${PATH2CONT}:ro" \
  "${IMAGE_NAME}" /check-syntax.sh
