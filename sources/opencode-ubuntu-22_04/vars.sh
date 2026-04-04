#!/usr/bin/env bash
set -ueo pipefail
export IMAGE_VER='009'
/usr/bin/env rm -rfv "sources/${TAG}/_shared"
/usr/bin/env cp -rfv _shared "sources/${TAG}"
/usr/bin/env cp -rfv podman.sh "sources/${TAG}/_shared"
