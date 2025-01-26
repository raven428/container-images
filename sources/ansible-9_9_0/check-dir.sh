#!/usr/bin/env bash
set -ueo pipefail
: "${DIR2CHECK:="."}"
: "${PATH2CONT:="/data"}"
: "${CONT_NAME:="linters-ansible-${USER}"}"
: "${IMAGE_NAME:="ghcr.io/raven428/container-images/ansible-9_9_0:latest"}"
DIR2CHECK="$(readlink -f "${DIR2CHECK}")"
/usr/bin/env podman run --rm \
  -i -w "${PATH2CONT}" \
  --name="${CONT_NAME}" \
  --hostname="${CONT_NAME}" \
  -v "${DIR2CHECK}:/data:ro" \
  "${IMAGE_NAME}" /check-syntax.sh
