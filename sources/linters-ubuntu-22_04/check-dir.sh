#!/usr/bin/env bash
set -ueo pipefail
: "${DIR2CHECK:="."}"
: "${PATH2CONT:="/data"}"
: "${CONT_NAME:="linters-generic-${USER}"}"
: "${TERRAFORM_DIR:="tf"}"
: "${PROM_RULES_DIR:="ansible/files/prometheus"}"
: "${USE_GITIGNORE:=""}"
: "${USE_LINTIGNORE:=""}"
: "${IMAGE_NAME:="ghcr.io/raven428/container-images/linters-ubuntu-22_04:001"}"
DIR2CHECK="$(readlink -f "${DIR2CHECK}")"
export TERRAFORM_DIR PROM_RULES_DIR USE_GITIGNORE USE_LINTIGNORE
/usr/bin/env podman run --rm \
  -i -w "${PATH2CONT}" \
  --name="${CONT_NAME}" \
  --hostname="${CONT_NAME}" \
  -e "TERRAFORM_DIR" -e "PROM_RULES_DIR" -e "USE_GITIGNORE" -e "USE_LINTIGNORE" \
  -v "${DIR2CHECK}:${PATH2CONT}:ro" \
  "${IMAGE_NAME}" /check-syntax.sh
