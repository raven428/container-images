#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='000'
  DEPENDS='ansible-11/'
  IMAGE_TEST='../../_shared/test/systemd/test.sh'
}
/usr/bin/env rm -rf "sources/${TAG}/_shared"
/usr/bin/env cp -rf _shared "sources/${TAG}"
