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
/usr/bin/env printf "\n———⟨ building: ⟩———\n"
TOTAL_RESULT=0
# shellcheck disable=2153
for IMAGE_DIR in "${IMAGES_DIRS[@]}"; do
  TAG=${IMAGE_DIR//sources\//}
  echo
  echo "building [${TAG}] from [${IMAGE_DIR}] dir…"
  DEPENDS=''
  BUILD_CONTEXT_DIR="${IMAGE_DIR}"
  PODMAN_EXTRA_ARGS=()
  NPM_PACKAGE=''
  NPM_CHECKS=()
  # shellcheck source=/dev/null
  source "${IMAGE_DIR}/vars.sh"
  [[ -n "${DEPENDS}" ]] && {
    echo "found depends [${DEPENDS}] to build"
    MANUAL_IMAGES_DIRS="${DEPENDS}" ${MY_BIN}
    echo "returning to [${TAG}] building…"
  }
  if [[ -n "${NPM_PACKAGE}" ]]; then
    if ! _npm_build "${TAG}" "${NPM_CHECKS[@]+"${NPM_CHECKS[@]}"}"; then
      echo "npm build failed for [${TAG}]"
      TOTAL_RESULT=$((TOTAL_RESULT + 1))
    fi
    unset IMAGE_TEST
    continue
  fi
  _set_image_version
  current_date="$(/usr/bin/env date '+%Y%m%d')"
  dev_tag_args=()
  _set_dev_tag_args dev_tag_args
  dev_build_args=()
  for dev_tag in "${dev_tag_args[@]+"${dev_tag_args[@]}"}"; do
    dev_build_args+=(-t "${dev_tag}")
  done
  lh_var='localhost' # DevSkim: ignore DS162092
  /usr/bin/env podman build \
    --network host \
    --build-arg TAG="${TAG}" \
    --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
    --build-arg PYENV_ROOT="${PYENV_ROOT}" \
    --cap-add=MAC_ADMIN,SYS_ADMIN \
    --security-opt apparmor=unconfined \
    -t "${lh_var}/${TAG}:local" \
    -t "${TARGET_REGISTRY}/${TAG}:latest" \
    -t "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}" \
    -t "${TARGET_REGISTRY}/${TAG}:${current_date}" \
    -t "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}-${current_date}" \
    "${dev_build_args[@]+"${dev_build_args[@]}"}" \
    "${PODMAN_EXTRA_ARGS[@]+"${PODMAN_EXTRA_ARGS[@]}"}" \
    "${BUILD_CONTEXT_DIR}"
  if [[ -n "${IMAGE_TEST:-}" ]]; then
    # shellcheck source=/dev/null
    source "${IMAGE_DIR}/${IMAGE_TEST}"
    if [[ ${TEST_RESULT:-1} -gt 0 ]]; then
      /usr/bin/env podman image rm -f \
        "${TARGET_REGISTRY}/${TAG}:latest" \
        "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}" \
        "${TARGET_REGISTRY}/${TAG}:${current_date}" \
        "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}-${current_date}" \
        "${dev_tag_args[@]+"${dev_tag_args[@]}"}"
      TOTAL_RESULT=$((TOTAL_RESULT + ${TEST_RESULT:-1}))
    fi
  fi
  unset IMAGE_TEST
done
exit "${TOTAL_RESULT}"
