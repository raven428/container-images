#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='001'
  IMAGE_TEST='../../_shared/test/systemd/test.sh'
  SHARED_ASSETS=(
    '_shared/test/systemd/test.sh:_shared/test/systemd/test.sh'
  )
}
stage_shared_assets
