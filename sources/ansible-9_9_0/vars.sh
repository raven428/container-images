#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='002'
  DEPENDS='ansible-ubuntu/ ansible-builder/'
}
/usr/bin/env cp -rf _shared "sources/${TAG}"
/usr/bin/env cp -fv _shared/install/ansible/Dockerfile "sources/${TAG}"
/usr/bin/env cp -fv _shared/install/ansible/* "sources/${TAG}/files/"
