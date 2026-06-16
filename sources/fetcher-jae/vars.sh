#!/usr/bin/env bash
# cspell:ignore jae
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='000'
  SHARED_ASSETS=()
}
stage_shared_assets
_upstream="sources/${TAG}/_shared/upstream"
# jae-jae/fetcher-mcp has no git tags; the SHA below pins the 0.3.9
# release commit (Playwright-based MCP server for fetching web content).
checkout_upstream 'https://github.com/jae-jae/fetcher-mcp.git' \
  '8754aff66e3d9207502207bf82a493f45f556bb8' "${_upstream}" # DevSkim: ignore DS173237
# shellcheck disable=2153
[[ -z "${PUSHING:-}" ]] && for _patch in "${IMAGE_DIR}/patches/"*.patch; do
  [[ -f "${_patch}" ]] || continue
  echo "applying ${_patch}"
  patch -d "${_upstream}" -p1 <"${_patch}"
done
# shellcheck disable=2034
BUILD_CONTEXT_DIR="${_upstream}"
unset _patch _upstream
