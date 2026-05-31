#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
PYTHON_VERSION='3.11.11'
# shellcheck disable=2034
PYENV_ROOT='/pye'
# Usage: checkout_upstream <repo_url> <repo_tag> <upstream_dir>
checkout_upstream() {
  local _repo_url="$1" _repo_tag="$2" _upstream="$3"
  if /usr/bin/env git -C "${_upstream}" rev-parse --git-dir >/dev/null 2>&1; then
    /usr/bin/env git -C "${_upstream}" reset --hard HEAD
    /usr/bin/env git -C "${_upstream}" clean -fd
    /usr/bin/env git -C "${_upstream}" fetch --tags
    /usr/bin/env git -C "${_upstream}" checkout "${_repo_tag}"
    /usr/bin/env git -C "${_upstream}" reset --hard "${_repo_tag}"
  else
    /usr/bin/env rm -rf "${_upstream}"
    /usr/bin/env git clone "${_repo_url}" "${_upstream}"
    /usr/bin/env git -C "${_upstream}" checkout "${_repo_tag}"
  fi
}
