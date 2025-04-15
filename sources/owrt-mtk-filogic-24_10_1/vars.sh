#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
IMAGE_VER='000'
/usr/bin/env rm -rfv "sources/${TAG}/files"
/usr/bin/env cp -rfv _shared/install/openwrt "sources/${TAG}/files"
