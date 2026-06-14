#!/usr/bin/env bash
# cspell:ignore bytedance
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='000'
  SHARED_ASSETS=()
}
stage_shared_assets
_upstream="sources/${TAG}/_shared/upstream"
# bytedance/UI-TARS-desktop is a pnpm monorepo; the tag below pins the
# last stable release of @agent-infra/mcp-server-browser, the
# Puppeteer-driven MCP server reused by player7. Dockerfile.http is
# identical between tags, so 1.1.5 is used for the upstream checkout
# while the npm package is pinned to 1.2.29 inside the Dockerfile.
checkout_upstream 'https://github.com/bytedance/UI-TARS-desktop.git' \
  '@agent-infra/mcp-server-browser@1.1.5' "${_upstream}"
# shellcheck disable=2153
for _patch in "${IMAGE_DIR}/patches/"*.patch; do
  [[ -f "${_patch}" ]] || continue
  echo "applying ${_patch}"
  patch -d "${_upstream}" -p1 <"${_patch}"
done
# The upstream Dockerfile pulls the published npm tarball via
# `npm i @agent-infra/mcp-server-browser@1.2.29 -g` and never COPYs
# sources, so the build context is kept inside the browser subpackage to
# avoid uploading the whole monorepo (node_modules, pnpm-lock, etc.).
# Stage auxiliary files (e.g. the dist/index.cjs signal-handler patch)
# into the build context so the Dockerfile can COPY them.
# shellcheck disable=2034
BUILD_CONTEXT_DIR="${_upstream}/packages/agent-infra/mcp-servers/browser"
cp -rv "${IMAGE_DIR}/files/." "${BUILD_CONTEXT_DIR}/"
# Use the HTTP variant: it exposes port 8088 (SSE + streamable HTTP)
# instead of the default stdio ENTRYPOINT.
# shellcheck disable=2034
PODMAN_EXTRA_ARGS=(--file "${BUILD_CONTEXT_DIR}/Dockerfile.http")
unset _patch _upstream
