#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=1091
MY_BIN="$(readlink -f "$0")"
MY_PATH="$(dirname "${MY_BIN}")"
# shellcheck source=/dev/null
source "${MY_PATH}/vars.sh"
/usr/bin/env printf "\n———⟨ building: ⟩———\n"
TOTAL_RESULT=0
# shellcheck disable=2153
for IMAGE_DIR in "${IMAGES_DIRS[@]}"; do
  TAG=${IMAGE_DIR//sources\//}
  echo
  echo "building [${TAG}] from [${IMAGE_DIR}] dir…"
  # shellcheck source=/dev/null
  source "${IMAGE_DIR}/vars.sh"
  /usr/bin/env docker build \
    --network host \
    -t "${TARGET_REGISTRY}/${TAG}:latest" \
    -t "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}" \
    "${IMAGE_DIR}"
  if [[ -n "${IMAGE_TEST:-}" ]]; then
    # shellcheck source=/dev/null
    source "${IMAGE_DIR}/${IMAGE_TEST}"
    if [[ ${TEST_RESULT:-1} -gt 0 ]]; then
      /usr/bin/env docker image rm -f \
        "${TARGET_REGISTRY}/${TAG}:latest" \
        "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}"
      TOTAL_RESULT=$((TOTAL_RESULT + ${TEST_RESULT:-1}))
    fi
  fi
  unset IMAGE_TEST
done
exit "${TOTAL_RESULT}"
