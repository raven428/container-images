#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='001'
  SHARED_ASSETS=(
    '_shared/install/ansible/common.sh:_shared/_shared/install/ansible/common.sh'
    'podman.sh:_shared/_shared/podman.sh'
    "sources/${TAG}/files/install.sh:_shared/files/install.sh"
  )
}
stage_shared_assets
# shellcheck disable=2034
BUILD_CONTEXT_DIR="sources/${TAG}/_shared"
# shellcheck disable=2034
PODMAN_EXTRA_ARGS=(--file "sources/${TAG}/Dockerfile")
