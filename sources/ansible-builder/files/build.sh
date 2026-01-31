#!/usr/bin/env bash
set -ueo pipefail
export PATH="$PYENV_ROOT/bin:$PATH"
export DEBIAN_FRONTEND='noninteractive'

apt-get update
apt-get install -y --no-install-recommends git curl libreadline-dev libsqlite3-dev less \
  libbz2-dev gcc g++ make zlib1g-dev libssl-dev libffi-dev liblzma-dev patch patchelf \
  libncursesw5-dev xz-utils file fuse
rm -rf /var/lib/apt/lists/*

# Install pyenv
curl -sLm 11 \
  https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv install "${PYTHON_VERSION}"

# Download appimagetool
APPIMAGE_BUILD_DIR='/usr/local/bin'
echo "Downloading appimagetool..."
mkdir -p "${APPIMAGE_BUILD_DIR}"
cd "${APPIMAGE_BUILD_DIR}"
curl -sLo appimagetool.AppImage \
  "https://github.com/AppImage/appimagetool/releases/latest/download/\
appimagetool-x86_64.AppImage"
chmod +x appimagetool.AppImage

echo "AppImage build environment ready:"
echo "  appimagetool: ${APPIMAGE_BUILD_DIR}/appimagetool.AppImage"
