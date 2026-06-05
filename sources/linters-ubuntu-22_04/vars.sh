#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='002'
  SHARED_ASSETS=(
    '_shared/prepare2check.sh:_shared/prepare2check.sh'
  )
}
stage_shared_assets
