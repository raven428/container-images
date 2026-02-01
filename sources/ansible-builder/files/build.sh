#!/usr/bin/env bash
set -ueo pipefail
export PATH="$PYENV_ROOT/bin:$PATH"
export DEBIAN_FRONTEND='noninteractive'

# Python version for AppImage builds
PYTHON_VERSION='3.11.11'
PYTHON_SHORT="${PYTHON_VERSION%.*}"
APPIMAGE_BUILD_DIR='/appimage-build'
JOBS="$(nproc)"

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
pyenv virtualenv "${PYTHON_VERSION}" ansible

# Build Python for AppImage
echo "Building Python ${PYTHON_VERSION} for AppImage..."
mkdir -p "${APPIMAGE_BUILD_DIR}"
cd "${APPIMAGE_BUILD_DIR}"

curl -sLo "Python-${PYTHON_VERSION}.tgz" \
  "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
tar -xf "Python-${PYTHON_VERSION}.tgz"
cd "Python-${PYTHON_VERSION}"

./configure \
  --prefix=/usr \
  --enable-optimizations \
  --with-ensurepip=install \
  --enable-shared

make -j"${JOBS}"
make DESTDIR="${APPIMAGE_BUILD_DIR}/python-install" install

# Download appimagetool
echo "Downloading appimagetool..."
cd "${APPIMAGE_BUILD_DIR}"
curl -sLo appimagetool.AppImage \
  "https://github.com/AppImage/appimagetool/releases/latest/download/\
appimagetool-x86_64.AppImage"
chmod +x appimagetool.AppImage

# Cleanup build artifacts but keep results
rm -rf "Python-${PYTHON_VERSION}" "Python-${PYTHON_VERSION}.tgz"

echo "AppImage build environment ready:"
echo "  Python install: ${APPIMAGE_BUILD_DIR}/python-install"
echo "  appimagetool: ${APPIMAGE_BUILD_DIR}/appimagetool.AppImage"
