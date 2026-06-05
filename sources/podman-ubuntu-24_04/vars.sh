#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='001'
  SHARED_ASSETS=(
    'podman.sh:_shared/podman.sh'
  )
}
stage_shared_assets
# shellcheck disable=2034
BUILD_CONTEXT_DIR="sources/${TAG}/_shared"
# shellcheck disable=2034
PODMAN_EXTRA_ARGS=(--file "sources/${TAG}/Dockerfile")
