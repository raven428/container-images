#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='001'
  SHARED_ASSETS=(
    '_shared/install/profile.sh:_shared/install/profile.sh'
    '_shared/sudoers:_shared/sudoers'
  )
}
stage_shared_assets
stage_profile "sources/${TAG}/_shared/profile-dmisu"
