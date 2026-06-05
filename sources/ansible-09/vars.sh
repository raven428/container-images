#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='002'
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
# shellcheck disable=2034
BUILD_CONTEXT_DIR="sources/${TAG}/_shared"
# shellcheck disable=2034
PODMAN_EXTRA_ARGS=(--file "sources/${TAG}/_shared/files/Dockerfile")
