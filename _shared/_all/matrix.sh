#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=1091
MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${MY_PATH}/vars.sh"
PKG_MATRIX='{"include":['
APP_MATRIX='{"include":['
app_count=0
# shellcheck disable=2153
for dir in "${IMAGES_DIRS[@]}"; do
  tag="${dir#sources/}"
  metadata="$(_probe_vars "${dir}" metadata)"
  package="${metadata%%|*}"
  app_image="${metadata#*|}"
  kind='img'
  [[ -n "${package}" ]] && kind='npm'
  PKG_MATRIX+="{\"kind\":\"${kind}\",\"tag\":\"${tag}\"},"
  if [[ "${app_image}" == '1' ]]; then
    APP_MATRIX+="{\"tag\":\"${tag}\"},"
    app_count=$((app_count + 1))
  fi
done
PKG_MATRIX="${PKG_MATRIX%,}]}"
if [[ ${app_count} -eq 0 ]]; then
  APP_MATRIX+='{"tag":"__skip__"},'
fi
APP_MATRIX="${APP_MATRIX%,}]}"
PKG_MATRIX="$(/usr/bin/env jq -c '.include |= sort_by(.kind, .tag)' <<<"${PKG_MATRIX}")"
APP_MATRIX="$(/usr/bin/env jq -c '.include |= sort_by(.tag)' <<<"${APP_MATRIX}")"
export PKG_MATRIX APP_MATRIX
