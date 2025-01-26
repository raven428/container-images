#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=1091
MY_BIN="$(readlink -f "$0")"
MY_PATH="$(dirname "${MY_BIN}")"
# shellcheck source=/dev/null
source "${MY_PATH}/vars.sh"
/usr/bin/env printf "\n———⟨ pushing: ⟩———\n"
# shellcheck disable=2153
for IMAGE_DIR in "${IMAGES_DIRS[@]}"; do
  TAG=${IMAGE_DIR//sources\//}
  echo
  echo "pushing [${TAG}] from [${IMAGE_DIR}] dir…"
  # shellcheck source=/dev/null
  source "${IMAGE_DIR}/vars.sh"
  /usr/bin/env podman push "${TARGET_REGISTRY}/${TAG}:latest"
  # shellcheck disable=2154
  /usr/bin/env podman push "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}"
  /usr/bin/env podman image rm -f \
    "${TARGET_REGISTRY}/${TAG}:latest" \
    "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}"
done
