#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='002'
  DEPENDS='ansible-6_7_0/'
  IMAGE_TEST='../../_shared/test/systemd/test.sh'
}
/usr/bin/env rm -rf "sources/${TAG}/_shared"
/usr/bin/env cp -rf _shared "sources/${TAG}"
