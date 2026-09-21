#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=1091
MY_BIN="$(readlink -f "$0")"
MY_PATH="$(dirname "${MY_BIN}")"
# shellcheck source=/dev/null
source "${MY_PATH}/vars.sh"
# shellcheck source=/dev/null
source "${MY_PATH}/../vars.sh"
# shellcheck source=/dev/null
source "${MY_PATH}/../npm/lib.sh"
/usr/bin/env printf "\n———⟨ pushing: ⟩———\n"
# shellcheck disable=2153
for IMAGE_DIR in "${IMAGES_DIRS[@]}"; do
  TAG=${IMAGE_DIR//sources\//}
  echo
  echo "pushing [${TAG}] from [${IMAGE_DIR}] dir…"
  NPM_PACKAGE=''
  eval "$(_build_vars_shunts "${IMAGE_DIR}/vars.sh")"
  # shellcheck disable=2034
  PUSHING=1
  # shellcheck source=/dev/null
  source "${IMAGE_DIR}/vars.sh"
  if [[ -n "${NPM_PACKAGE}" ]]; then
    _npm_push "${TAG}"
    continue
  fi
  current_date="$(/usr/bin/env date '+%Y%m%d')"
  dev_tag_args=()
  _set_dev_tag_args dev_tag_args
  if [[ "${IMAGE_VER}" != "999" ]]; then
    /usr/bin/env podman push "${TARGET_REGISTRY}/${TAG}:latest"
    /usr/bin/env podman push "${TARGET_REGISTRY}/${TAG}:${current_date}"
  fi
  /usr/bin/env podman push "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}"
  /usr/bin/env podman push "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}-${current_date}"
  for dev_image in "${dev_tag_args[@]+"${dev_tag_args[@]}"}"; do
    /usr/bin/env podman push "${dev_image}"
  done
  /usr/bin/env podman image rm -f \
    "${TARGET_REGISTRY}/${TAG}:latest" \
    "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}" \
    "${TARGET_REGISTRY}/${TAG}:${current_date}" \
    "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}-${current_date}" \
    "${dev_tag_args[@]+"${dev_tag_args[@]}"}"
done
