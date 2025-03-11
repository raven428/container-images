#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='002'
  IMAGE_TEST='../../_shared/test/systemd/test.sh'
  DEPENDS='ansible-11_1_0/'
}
/usr/bin/env rm -rfv "sources/${TAG}/_shared"
/usr/bin/env cp -rfv _shared "sources/${TAG}"
