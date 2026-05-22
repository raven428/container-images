#!/usr/bin/env bash
set -ueo pipefail
_dest="${1}"
_tmp="$(/usr/bin/env mktemp -d '/tmp/profile-XXXXX')"
trap 'rm -rf "${_tmp}"' INT QUIT ABRT TERM EXIT
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
