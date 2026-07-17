#!/usr/bin/env bash
set -ueo pipefail
# Provides install_profile <dest> — clones the dotfiles repo into <dest>.
# Source this file; do not execute it directly.
install_profile() {
  local _dest="$1"
  # run the body in a subshell so cleanup traps stay fully local:
  # RETURN would leak into the enclosing shell and fire on any later
  # function return; EXIT would clobber a caller's EXIT trap; a subshell
  # scope isolates both and also covers signal delivery. _tmp is created
  # inside the subshell so the trap is armed right after allocation and
  # there is no window where an orphan directory can leak on failure
  (
    _tmp="$(/usr/bin/env mktemp -d '/tmp/profile-XXXXX')"
    # shellcheck disable=2064
    trap "/usr/bin/env rm -rf '${_tmp}'" EXIT HUP INT QUIT TERM ABRT
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
  )
}
