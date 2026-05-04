#!/usr/bin/env bash
set -euo pipefail
# Builds AppImage for TAG in a podman container.
# Usage: TAG=ansible-11 ./_shared/_all/appimage.sh
#        TAG=texlive-myminimal ./_shared/_all/appimage.sh
: "${TAG:?TAG environment variable must be set (e.g., ansible-11)}"
echo "Building AppImage for ${TAG} in container…"
if [[ -f "sources/${TAG}/vars.sh" ]]; then
  # shellcheck source=/dev/null
  source "sources/${TAG}/vars.sh"
else
  IMAGE_VER="${IMAGE_VER:-000}"
fi
TARGET_REGISTRY="${TARGET_REGISTRY:-ghcr.io/raven428/container-images}"
mkdir -p appimage-output
# Select build image and inner script based on tag prefix
case "${TAG}" in
texlive-*)
  BUILD_IMAGE="${TARGET_REGISTRY}/${TAG}:latest"
  BUILD_SCRIPT='texlive/build-appimage.sh'
  ;;
*)
  BUILD_IMAGE="${TARGET_REGISTRY}/ansible-appimage:latest"
  BUILD_SCRIPT='ansible/build-appimage.sh'
  ;;
esac
podman run --log-driver=none --rm --device /dev/fuse --cap-add SYS_ADMIN \
  -v "$PWD:/workspace:ro" -v "$PWD/appimage-output:/output:z" --workdir /workspace \
  -e TAG="${TAG}" -e IMAGE_VER="${IMAGE_VER}" "${BUILD_IMAGE}" \
  bash "/workspace/_shared/install/${BUILD_SCRIPT}"
echo "AppImage built successfully: appimage-output/${TAG}-${IMAGE_VER}.AppImage"
