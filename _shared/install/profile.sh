#!/usr/bin/env bash
set -ueo pipefail
# Provides install_profile <dest> — clones the dotfiles repo into <dest>.
# Source this file; do not execute it directly.
install_profile() {
  local _dest="$1"
  local _tmp
  _tmp="$(/usr/bin/env mktemp -d '/tmp/profile-XXXXX')"
  # trap is scoped to this function invocation only
  # shellcheck disable=2064
  trap "/usr/bin/env rm -rf '${_tmp}'" RETURN
  /usr/bin/env git clone 'https://github.com/raven428/profile.git' "${_tmp}"
  /usr/bin/env cat <<'EOF' >"${_tmp}/.git/config"
[core]
  repositoryformatversion = 0
  filemode = true
  bare = false
  logallrefupdates = true
[remote "origin"]
  url = git@github.com:raven428/profile.git
  fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
  remote = origin
  merge = refs/heads/master
[log]
  showSignature = false
[user]
  name = Dmitry Sukhodoev
  email = raven428@gmail.com
EOF
  /usr/bin/env cp -r "${_tmp}" "${_dest}"
}
