#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
IMAGE_VER='000'
/usr/bin/env cp 'sources/ansible-ubuntu/files/install.sh' "sources/${TAG}/files"
/usr/bin/env rm -rf "sources/${TAG}/_shared"
/usr/bin/env cp -rf _shared "sources/${TAG}"
/usr/bin/env cp -fv podman.sh "sources/${TAG}"
