#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='000'
  SHARED_ASSETS=()
}
stage_shared_assets
_upstream="sources/${TAG}/_shared/upstream"
# microsoft/playwright-mcp v0.0.76 ships serverInfo.version 1.61.0-alpha-1781023400000,
# which is exactly the build running on player8.
checkout_upstream 'https://github.com/microsoft/playwright-mcp.git' 'v0.0.76' \
  "${_upstream}"
# shellcheck disable=2153
[[ -z "${PUSHING:-}" ]] && for _patch in "${IMAGE_DIR}/patches/"*.patch; do
  [[ -f "${_patch}" ]] || continue
  echo "applying ${_patch}"
  patch -d "${_upstream}" -p1 <"${_patch}"
done
# shellcheck disable=2034
BUILD_CONTEXT_DIR="${_upstream}"
unset _patch _upstream
