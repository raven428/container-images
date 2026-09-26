#!/usr/bin/env bash
# cspell:ignore patchset
set -ueo pipefail
# shellcheck disable=2034
{
  NPM_PACKAGE='@raven428/pi-web'
  UPSTREAM_URL='https://github.com/jmfederico/pi-web.git'
  UPSTREAM_VER='v1.202609.0'
  PATCHSET='1'
  NPM_CHECKS=(
    'npm run typecheck'
  )
  SHARED_ASSETS=()
}
if [[ -z "${PUSHING:-}" ]]; then
  stage_shared_assets
  _upstream="sources/${TAG}/_shared/upstream"
  checkout_upstream "${UPSTREAM_URL}" "${UPSTREAM_VER}" "${_upstream}"
  # shellcheck disable=2153
  for _patch in "${IMAGE_DIR}/patches/"*.patch; do
    [[ -f "${_patch}" ]] || continue
    echo "applying ${_patch}"
    /usr/bin/env patch -d "${_upstream}" -p1 <"${_patch}"
  done
  unset _patch _upstream
fi
