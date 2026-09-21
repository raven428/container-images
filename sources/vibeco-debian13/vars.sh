#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='003'
  IMAGE_TEST='../../_shared/test/systemd/test.sh'
  SHARED_ASSETS=(
    '_shared/install/systemd-docker/:_shared/install/systemd-docker'
    '_shared/test/systemd/test.sh:_shared/test/systemd/test.sh'
    '_shared/install/coder.sh:_shared/install/coder.sh'
    '_shared/install/profile.sh:_shared/install/profile.sh'
    '_shared/install/debian/13/podman.sh:_shared/podman.sh'
    '_shared/sudoers:_shared/sudoers'
  )
}
if [[ -z "${PUSHING:-}" ]]; then
  stage_shared_assets
  stage_profile "sources/${TAG}/_shared/profile-dmisu"
fi
