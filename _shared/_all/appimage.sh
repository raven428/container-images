#!/usr/bin/env bash
set -euo pipefail

# Helper script to build AppImage in podman container
# Usage: TAG=ansible-11 ./_shared/_all/build-appimage-in-container.sh

: "${TAG:?TAG environment variable must be set (e.g., ansible-11)}"

echo "Building AppImage for ${TAG} in container..."

# Get IMAGE_VER from vars.sh
# shellcheck source=/dev/null
source "sources/${TAG}/vars.sh"

# Create output directory
mkdir -p appimage-output

# Run build in container
podman run --log-driver=none --rm --device /dev/fuse --cap-add SYS_ADMIN \
  -v "$PWD:/workspace:ro" \
  -v "$PWD/appimage-output:/output:z" \
  --workdir /workspace \
  -e TAG="${TAG}" \
  -e IMAGE_VER="${IMAGE_VER}" \
  ghcr.io/raven428/container-images/ansible-appimage:latest \
  bash /workspace/_shared/install/ansible/build-appimage.sh

echo "AppImage built successfully: appimage-output/${TAG}-${IMAGE_VER}.AppImage"
