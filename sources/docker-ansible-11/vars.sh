#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='002'
  DEPENDS='ansible-11/'
  IMAGE_TEST='../../_shared/test/systemd/test.sh'
  SHARED_ASSETS=(
    '_shared/install/docker.sh:_shared/install/docker.sh'
    '_shared/test/systemd/test.sh:_shared/test/systemd/test.sh'
  )
}
stage_shared_assets
