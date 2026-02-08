#!/usr/bin/env bash
set -ueo pipefail
export IMAGE_VER='000'
/usr/bin/env rm -rfv "sources/${TAG}/_shared"
/usr/bin/env cp -rfv _shared "sources/${TAG}"
