#!/usr/bin/env bash
set -euo pipefail

# This script builds AppImage for ansible containers
# It can be used for ansible-06 through ansible-11
# Usage: TAG=ansible-11 IMAGE_VER=001 build-appimage.sh
# Pre-built Python and appimagetool must be in /appimage-build

# Validate required env vars
: "${TAG:?TAG environment variable must be set (e.g., ansible-11)}"
: "${IMAGE_VER:?IMAGE_VER environment variable must be set (e.g., 001)}"

# Paths to pre-built components
APPIMAGE_BUILD_DIR='/appimage-build'
PYTHON_INSTALL="${APPIMAGE_BUILD_DIR}/python-install"
APPIMAGETOOL="${APPIMAGE_BUILD_DIR}/appimagetool.AppImage"

# Validate pre-built components exist
if [[ ! -d "${PYTHON_INSTALL}/usr" ]]; then
  echo "Error: Pre-built Python not found at ${PYTHON_INSTALL}/usr"
  echo "Make sure ansible-builder container was built correctly"
  exit 1
fi

if [[ ! -f "${APPIMAGETOOL}" ]]; then
  echo "Error: appimagetool not found at ${APPIMAGETOOL}"
  echo "Make sure ansible-builder container was built correctly"
  exit 1
fi

# Python version is always 3.11.11 (built into ansible-builder)
PYTHON_VERSION="3.11.11"
PYTHON_SHORT="${PYTHON_VERSION%.*}"

# Build config
APP_NAME="${TAG}-${IMAGE_VER}"
APPDIR="/tmp/appimage/${TAG}"
REQUIREMENTS="/workspace/sources/${TAG}/files/requirements.txt"

echo "Building AppImage for ${TAG} with Python ${PYTHON_VERSION}"

# Clean previous build
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Copy pre-built Python installation
echo "Copying pre-built Python installation..."
cp -a "${PYTHON_INSTALL}/usr" "$APPDIR/"

cd "$APPDIR"

# Create sitecustomize.py for portable shebangs
echo "Creating sitecustomize.py for portable shebangs..."
cat > "usr/lib/python${PYTHON_SHORT}/sitecustomize.py" << 'SITECUSTOMIZE_EOF'
from pip._vendor.distlib.scripts import ScriptMaker
ScriptMaker._build_shebang = lambda self, exe, post: b'#!/usr/bin/env python3' + post + b'\n'
SITECUSTOMIZE_EOF

# Patch rpath
echo "Patching rpath..."
find usr -type f -executable -exec patchelf \
  --set-rpath '$ORIGIN/../lib:$ORIGIN/../lib64' {} \; 2>/dev/null || true

# Create venv
echo "Creating virtual environment..."
./usr/bin/python${PYTHON_SHORT} -m venv usr/venv

# Fix absolute symlink to relative (venv creates absolute symlink to python)
echo "Fixing python symlink to be relative..."
cd usr/venv/bin
rm -f python${PYTHON_SHORT}
ln -s ../../bin/python${PYTHON_SHORT} python${PYTHON_SHORT}
cd "$APPDIR"

# Activate venv
source usr/venv/bin/activate

# Upgrade tooling
echo "Upgrading pip, setuptools, wheel..."
pip install --upgrade pip setuptools wheel

# Install from requirements.txt
if [[ -f "${REQUIREMENTS}" ]]; then
  echo "Installing packages from requirements.txt..."
  pip install -r "${REQUIREMENTS}"
else
  echo "Error: requirements.txt not found at ${REQUIREMENTS}"
  exit 1
fi

deactivate

# Create AppRun
echo "Creating AppRun..."
cat > AppRun << EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
CMD="\$(basename "\$0")"

export LD_LIBRARY_PATH="\$HERE/usr/lib:\$HERE/usr/lib64:\$LD_LIBRARY_PATH"
export PATH="\$HERE/usr/venv/bin:\$HERE/usr/bin:\$PATH"
export PYTHONHOME="\$HERE/usr"
export PYTHONPATH="\$HERE/usr/lib/python${PYTHON_SHORT}"

# Autodispatch mode
if [[ "\$CMD" != "AppRun" && -x "\$HERE/usr/venv/bin/\$CMD" ]]; then
  exec "\$HERE/usr/venv/bin/\$CMD" "\$@"
fi

if [[ \$# -eq 0 ]]; then
  exec "\$HERE/usr/venv/bin/python"
else
  exec "\$@"
fi
EOF

chmod +x AppRun

# Create desktop file
echo "Creating desktop file..."
cat > "${APP_NAME}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=${APP_NAME}
Icon=${APP_NAME}
Categories=Development;
Terminal=true
EOF

# Create minimal PNG icon
echo "Creating icon..."
printf '\x89PNG\r\n\x1a\n' > "${APP_NAME}.png"

# Build AppImage
echo "Building AppImage..."
"${APPIMAGETOOL}" "${APPDIR}" "${APP_NAME}.AppImage"

# Copy to output
mkdir -p /output
cp "${APP_NAME}.AppImage" /output/

echo
echo "Build finished successfully!"
echo "  /output/${APP_NAME}.AppImage"
