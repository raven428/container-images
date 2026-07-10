#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='000'
  SHARED_ASSETS=()
}
stage_shared_assets
_upstream="sources/${TAG}/_shared/upstream"
# Upstream has no tags; pin to a specific commit on master.
checkout_upstream 'https://github.com/eduard256/ozon-mcp-server.git' \
  '1f2f7e3dcd301a015e93301f0cfe66ffc0b4c647' "${_upstream}" # DevSkim: ignore DS173237
# shellcheck disable=2153
[[ -z "${PUSHING:-}" ]] && for _patch in "${IMAGE_DIR}/patches/"*.patch; do
  [[ -f "${_patch}" ]] || continue
  echo "applying ${_patch}"
  patch -d "${_upstream}" -p1 <"${_patch}"
done
# shellcheck disable=2034
BUILD_CONTEXT_DIR="${_upstream}"
unset _patch _upstream
