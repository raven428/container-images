#!/usr/bin/env bash
set -euo pipefail

# Build config
PYTHON_VERSION="3.11.11"
APP_NAME="ansible-11"
APPDIR="$PWD/../app-image/ansible-11"
BUILD="$PWD/../app-image/build"
JOBS="$(nproc)"

# Clean previous build
rm -rf "$APPDIR" "$BUILD"
mkdir -p "$APPDIR" "$BUILD"

cd "$BUILD"

# Download Python
if [[ ! -f Python-${PYTHON_VERSION}.tgz ]]; then
  wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
fi

# Extract
tar -xf Python-${PYTHON_VERSION}.tgz
cd Python-${PYTHON_VERSION}

# Build Python
./configure \
  --prefix=/usr \
  --enable-optimizations \
  --with-ensurepip=install \
  --enable-shared

make -j"$JOBS"
make DESTDIR="$APPDIR" install

cd "$APPDIR"

# Patch rpath
find usr -type f -executable -exec patchelf \
  --set-rpath '$ORIGIN/../lib:$ORIGIN/../lib64' {} \;

# Create venv
./usr/bin/python3.11 -m venv usr/venv

# Activate venv
source usr/venv/bin/activate

# Upgrade tooling
pip install --upgrade pip setuptools wheel

# Install core tools
pip install \
  ansible \
  molecule \
  molecule-plugins[docker] \
  yamllint

# Install user requirements if exists
if [[ -f "$PWD/../requirements.txt" ]]; then
  pip install -r "$PWD/../requirements.txt"
fi

deactivate

# Create AppRun
cat > AppRun << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
CMD="$(basename "$0")"

export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib64:$LD_LIBRARY_PATH"
export PATH="$HERE/usr/venv/bin:$HERE/usr/bin:$PATH"
export PYTHONHOME="$HERE/usr"
export PYTHONPATH="$HERE/usr/lib/python3.11"

# Autodispatch mode
if [[ "$CMD" != "AppRun" && -x "$HERE/usr/venv/bin/$CMD" ]]; then
  exec "$HERE/usr/venv/bin/$CMD" "$@"
fi

if [[ $# -eq 0 ]]; then
  exec "$HERE/usr/venv/bin/python"
else
  exec "$@"
fi
EOF

chmod +x AppRun

cd ..

# Download appimagetool
if [[ ! -f appimagetool.AppImage ]]; then
  wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool.AppImage
  chmod +x appimagetool.AppImage
fi

# Build AppImage
./appimagetool.AppImage ${APPDIR} "${APP_NAME}.AppImage"

echo
echo "Build finished:"
echo "  ${APP_NAME}.AppImage"
