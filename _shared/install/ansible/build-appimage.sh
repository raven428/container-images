#!/usr/bin/env bash
set -euo pipefail

# This script builds AppImage for ansible containers
# It can be used for ansible-06 through ansible-11
# Usage: TAG=ansible-11 IMAGE_VER=001 build-appimage.sh
# Requires pyenv with Python and appimagetool in /usr/local/bin

# Validate required env vars
: "${TAG:?TAG environment variable must be set (e.g., ansible-11)}"
: "${IMAGE_VER:?IMAGE_VER environment variable must be set (e.g., 001)}"

# Paths to pre-built components
APPIMAGETOOL='/usr/local/bin/appimagetool.AppImage'
# Validate appimagetool exists
if [[ ! -f "${APPIMAGETOOL}" ]]; then
  echo "Error: appimagetool not found at ${APPIMAGETOOL}"
  echo "Make sure ansible-appimage container was built correctly"
  exit 1
fi

# Build config
APP_NAME="${TAG}-${IMAGE_VER}"
APPDIR="${PYENV_ROOT}/versions/${PYTHON_VERSION}"
REQUIREMENTS="/workspace/sources/${TAG}/files/requirements.txt"

echo "Building AppImage for ${TAG} with Python ${PYTHON_VERSION}"

# Prepare AppDir structure
echo "Preparing AppDir from pyenv installation..."
cd "$APPDIR"

# Create sitecustomize.py for portable shebangs
echo "Creating sitecustomize.py for portable shebangs..."
SITE_PACKAGES_DIR="$(find lib -type d -name site-packages | head -n1)"
cat >"${SITE_PACKAGES_DIR}/sitecustomize.py" <<'SITECUSTOMIZE_EOF'
from pip._vendor.distlib.scripts import ScriptMaker
ScriptMaker._build_shebang = lambda self, exe, post: b'#!/usr/bin/env python3' + post + b'\n'
SITECUSTOMIZE_EOF

# Upgrade pip in base pyenv installation
echo "Upgrading pip, setuptools, wheel..."
bin/python -m pip install --upgrade --force-reinstall pip setuptools wheel

# Install from requirements.txt
if [[ -f "${REQUIREMENTS}" ]]; then
  echo "Installing packages from requirements.txt..."
  bin/python -m pip install -r "${REQUIREMENTS}"
else
  echo "Error: requirements.txt not found at ${REQUIREMENTS}"
  exit 1
fi

# Source common functions
# shellcheck disable=SC1091
source /workspace/_shared/install/ansible/common.sh

# Extract ansible version from TAG (e.g., "ansible-11" -> "11")
ANSIBLE_VERSION="${TAG#ansible-}"

# Cleanup Python packages
cleanup_python_packages "$APPDIR"

# Apply patches based on ansible version
PATCH_DIR="/workspace/_shared/install/ansible"
apply_flush_line_patch "$APPDIR" "${PATCH_DIR}/flush-line.diff" "${ANSIBLE_VERSION}"
apply_async_check_patch "$APPDIR" "${PATCH_DIR}/async-check.diff" "${ANSIBLE_VERSION}"

# Return to APPDIR after patches (patch functions do cd)
cd "$APPDIR"

# Patch rpath for all executables
# echo "Patching rpath..."
# find . -type f -executable -exec patchelf \
#   --set-rpath '$ORIGIN/../lib:$ORIGIN/../lib64' {} \; 2>/dev/null || true

# Create AppRun
echo "Creating AppRun..."
cat >AppRun <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
CMD="$(basename "$0")"
export LD_LIBRARY_PATH="${HERE}/lib:${HERE}/lib64:${LD_LIBRARY_PATH}"
export PATH="${HERE}/bin:${PATH}"
export PYTHONHOME="${HERE}"
export PYTHONPATH="${HERE}/lib/python"
: "${ANSIBLE_USERDIR:="${HOME}/.ansible"}"
/usr/bin/env mkdir -vp "${ANSIBLE_USERDIR}"/{ssh,tmp}
/usr/bin/env cat >"${ANSIBLE_USERDIR}/ssh/config" <<SSHCONFIG
# ssh config for Ansible
SendEnv=LC_*
SendEnv=LANG
SendEnv=ANSIBLE_*
SendEnv=RSYNC_RSH
ForwardAgent=yes
ControlMaster=auto
ControlPersist=111m
HostKeyAlgorithms=ssh-ed25519
StrictHostKeyChecking=accept-new
PreferredAuthentications=publickey
ControlPath=${ANSIBLE_USERDIR}/ssh/host-%r@%h:%p
UserKnownHostsFile=${ANSIBLE_USERDIR}/ssh/known_hosts

Include ${ANSIBLE_USERDIR}/ssh/conf.d/*
SSHCONFIG
export ANSIBLE_SSH_ARGS="-F ${ANSIBLE_USERDIR}/ssh/config"
# Autodispatch mode
if [[ "${CMD}" != "AppRun" && -x "${HERE}/bin/${CMD}" ]]; then
  exec "${HERE}/bin/${CMD}" "$@"
fi
if [[ $# -eq 0 ]]; then
  exec "${HERE}/bin/python"
else
  exec "$@"
fi
EOF

chmod +x AppRun

# Create desktop file
echo "Creating desktop file..."
cat >"${APP_NAME}.desktop" <<EOF
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
printf '\x89PNG\r\n\x1a\n' >"${APP_NAME}.png"

# Build AppImage
echo "Building AppImage..."
"${APPIMAGETOOL}" "${APPDIR}" "${APP_NAME}.AppImage"

# Copy to output
mkdir -p /output
cp "${APP_NAME}.AppImage" /output/

echo
echo "Build finished successfully!"
echo "  /output/${APP_NAME}.AppImage"
