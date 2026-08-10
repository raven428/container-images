#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='003'
  DEPENDS='ansible-ubuntu/ ansible-builder/'
  SHARED_ASSETS=(
    '_shared/install/ansible/:_shared/files'
    '_shared/sudoers:_shared/_shared/sudoers'
    '_shared/prepare2check.sh:_shared/_shared/prepare2check.sh'
    '_shared/install/ansible/common.sh:_shared/_shared/install/ansible/common.sh'
    "sources/${TAG}/files/requirements.txt:_shared/files/requirements.txt"
  )
}
stage_shared_assets
/usr/bin/env cat "sources/${TAG}/_shared/files/async-check.diff" |
  /usr/bin/env awk \
    '/^--- .+site-packages\/ansible\/plugins\/action\/__init__/ { exit } { print }' |
  /usr/bin/env sed -rz \
    's/\x0d\x0a/\x0a/g; s/\x0d/\x0a/g; s/[ \t]+\x0a/\x0a/g; s/\x0a*$/\x0a/g' \
    >"sources/${TAG}/_shared/files/async-check-new.diff"
/usr/bin/env mv -fv "sources/${TAG}/_shared/files/async-check-new.diff" \
  "sources/${TAG}/_shared/files/async-check.diff"
# shellcheck disable=2034
BUILD_CONTEXT_DIR="sources/${TAG}/_shared"
# shellcheck disable=2034
PODMAN_EXTRA_ARGS=(--file "sources/${TAG}/_shared/files/Dockerfile")
