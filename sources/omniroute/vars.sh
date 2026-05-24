#!/usr/bin/env bash
set -ueo pipefail
export IMAGE_VER='000'
_repo_tag='v3.8.1'
mkdir -p "sources/${TAG}/_shared"
_upstream="sources/${TAG}/_shared/upstream"
if /usr/bin/env git -C "${_upstream}" rev-parse --git-dir >/dev/null 2>&1; then
  /usr/bin/env git -C "${_upstream}" reset --hard HEAD
  /usr/bin/env git -C "${_upstream}" clean -fd
  /usr/bin/env git -C "${_upstream}" fetch --tags
  /usr/bin/env git -C "${_upstream}" checkout "${_repo_tag}"
  /usr/bin/env git -C "${_upstream}" reset --hard "${_repo_tag}"
else
  /usr/bin/env rm -rf "${_upstream}"
  /usr/bin/env git clone 'https://github.com/diegosouzapw/OmniRoute.git' "${_upstream}"
  /usr/bin/env git -C "${_upstream}" checkout "${_repo_tag}"
fi
# shellcheck disable=2153
for _patch in "${IMAGE_DIR}/patches/"*.patch; do
  [[ -f "${_patch}" ]] || continue
  echo "applying ${_patch}"
  patch -d "${_upstream}" -p1 <"${_patch}"
done
# shellcheck disable=2034
BUILD_CONTEXT_DIR="${_upstream}"
# shellcheck disable=2034
PODMAN_EXTRA_ARGS=(--target runner-base)
unset _patch _upstream _repo_tag
