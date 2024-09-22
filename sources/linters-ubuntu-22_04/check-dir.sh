#!/usr/bin/env bash
set -ueo pipefail
: "${DIR2CHECK:="."}"
: "${PATH2CONT:="/data"}"
: "${CONT_NAME:="linters-generic-${USER}"}"
: "${PROM_RULES_DIR:="ansible/files/prometheus"}"
: "${IMAGE_NAME:="ghcr.io/raven428/container-images/linters-ubuntu-22_04:latest"}"
DIR2CHECK="$(readlink -f "${DIR2CHECK}")"
export PROM_RULES_DIR
/usr/bin/env docker run --rm \
  -it -w "${PATH2CONT}" \
  --name="${CONT_NAME}" \
  --hostname="${CONT_NAME}" \
  -e "PROM_RULES_DIR" \
  -v "${DIR2CHECK}:/data:ro" \
  "${IMAGE_NAME}" /check-syntax.sh