#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=1091
MY_BIN="$(readlink -f "$0")"
MY_PATH="$(dirname "${MY_BIN}")"
# shellcheck source=/dev/null
source "${MY_PATH}/vars.sh" || source "./vars.sh"
DIR_SON='['
# shellcheck disable=2153
for dir in "${IMAGES_DIRS[@]}"; do
  DIR_SON="${DIR_SON}\"${dir//sources\//}\","
done
export DIR_SON="${DIR_SON%,}]"
