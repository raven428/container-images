#!/usr/bin/env bash
set -ueo pipefail
: "${DIR2CHECK:="."}"
: "${PATH2CONT:="/data"}"
: "${CONT_NAME:="linters-generic-${USER}"}"
: "${TERRAFORM_DIR:="tf"}"
: "${PROM_RULES_DIR:="ansible/files/prometheus"}"
: "${IMAGE_NAME:="ghcr.io/raven428/container-images/linters-ubuntu-22_04:latest"}"
DIR2CHECK="$(readlink -f "${DIR2CHECK}")"
export TERRAFORM_DIR PROM_RULES_DIR
/usr/bin/env podman run --rm \
  -i -w "${PATH2CONT}" \
  --name="${CONT_NAME}" \
  --hostname="${CONT_NAME}" \
  -e "TERRAFORM_DIR" \
  -e "PROM_RULES_DIR" \
  -v "${DIR2CHECK}:${PATH2CONT}:ro" \
  "${IMAGE_NAME}" /check-syntax.sh
