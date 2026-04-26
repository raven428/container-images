#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
IMAGE_VER='000'
/usr/bin/env rm -rfv "sources/${TAG}/_shared"
