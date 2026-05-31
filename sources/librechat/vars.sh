#!/usr/bin/env bash
set -ueo pipefail
export IMAGE_VER='000'
mkdir -p "sources/${TAG}/_shared"
_upstream="sources/${TAG}/_shared/upstream"
checkout_upstream \
  'https://github.com/danny-avila/LibreChat.git' \
  'v0.8.5' \
  "${_upstream}"
# shellcheck disable=2153
for _patch in "${IMAGE_DIR}/patches/"*.patch; do
  [[ -f "${_patch}" ]] || continue
  echo "applying ${_patch}"
  patch -d "${_upstream}" -p1 <"${_patch}"
done
# shellcheck disable=2034
BUILD_CONTEXT_DIR="${_upstream}"
unset _patch _upstream
