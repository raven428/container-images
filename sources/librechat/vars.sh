#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='002'
  SHARED_ASSETS=(
    'podman.sh:_shared/podman.sh'
  )
}
stage_shared_assets
_upstream="sources/${TAG}/_shared/upstream"
checkout_upstream 'https://github.com/danny-avila/LibreChat.git' 'v0.8.5' "${_upstream}"
# shellcheck disable=2153
cp -rv "${IMAGE_DIR}/files" "${_upstream}/"
cp -v "${IMAGE_DIR}/setup-podman.sh" "${_upstream}/"
cp -v "${IMAGE_DIR}/_shared/podman.sh" "${_upstream}/"
[[ -z "${PUSHING:-}" ]] && for _patch in "${IMAGE_DIR}/patches/"*.patch; do
  [[ -f "${_patch}" ]] || continue
  echo "applying ${_patch}"
  patch -d "${_upstream}" -p1 <"${_patch}"
done
# shellcheck disable=2034
BUILD_CONTEXT_DIR="${_upstream}"
unset _patch _upstream
