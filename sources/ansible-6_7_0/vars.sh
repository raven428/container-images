#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='002'
  DEPENDS='ansible-builder/'
}
/usr/bin/env cp -fv _shared/install/ansible/Dockerfile "sources/${TAG}"
/usr/bin/env cp -fv _shared/install/ansible/* "sources/${TAG}/files/"
/usr/bin/env sed -i 's|^\(.*patch -p0 < /files/flush-line.diff.*\)|# \1|' \
  "sources/${TAG}/files/build.sh"
