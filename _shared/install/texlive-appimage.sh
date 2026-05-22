#!/usr/bin/env bash
# cspell:ignore kpathsea TEXMFROOT SELFAUTOPARENT TEXMFCNF TEXMFSYSVAR
# cspell:ignore TEXMFSYSCONFIG updmap TEXMFVAR TEXMFCONFIG mktexfmt fmtutil
# cspell:ignore TEXMFHOME OSFONTDIR opentype cachedir
set -euo pipefail
# Builds AppImage for texlive-* tags.
# Runs inside the texlive-myminimal container (or any derivative).
# All TeX Live files are already present at /usr/local/texlive.
# Usage: TAG=texlive-myminimal IMAGE_VER=003 build-appimage.sh
# Requires appimagetool at /usr/local/bin/appimagetool.AppImage
: "${TAG:?TAG environment variable must be set (e.g., texlive-myminimal)}"
: "${IMAGE_VER:?IMAGE_VER environment variable must be set (e.g., 003)}"
APPIMAGETOOL='/usr/local/bin/appimagetool.AppImage'
# Install tools required by appimagetool that are not in the texlive image,
# and download appimagetool itself
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y --no-install-recommends fuse file curl
rm -rf /var/lib/apt/lists/*
if [[ ! -x "${APPIMAGETOOL}" ]]; then
  echo "Downloading appimagetool…"
  curl -sLo "${APPIMAGETOOL}" "https://github.com/AppImage/appimagetool/releases/latest/\
download/appimagetool-$(uname -m).AppImage"
  chmod +x "${APPIMAGETOOL}"
fi
APP_NAME="${TAG}-${IMAGE_VER}"
APPDIR="/tmp/${APP_NAME}.AppDir"
rm -rf "${APPDIR}"
# Detect texlive year directory (e.g. 2024)
TL_YEAR="$(find /usr/local/texlive/ -mindepth 1 -maxdepth 1 -type d \
  -name '[0-9][0-9][0-9][0-9]' -printf '%f\n' | sort | head -1)"
if [[ -z "${TL_YEAR}" ]]; then
  echo "Error: cannot detect TeX Live year in /usr/local/texlive/" >&2
  exit 1
fi
echo "Detected TeX Live year: ${TL_YEAR}"
# Detect arch-specific bin subdir (e.g. x86_64-linux)
TL_BIN_ARCH="$(find "/usr/local/texlive/${TL_YEAR}/bin/" -mindepth 1 -maxdepth 1 -type d \
  -printf '%f\n' | head -1)"
if [[ -z "${TL_BIN_ARCH}" ]]; then
  echo "Error: cannot detect TeX Live bin arch directory" >&2
  exit 1
fi
echo "Detected TeX Live bin arch: ${TL_BIN_ARCH}"
# Copy entire /usr/local/texlive — packages, fonts, formats, binaries
echo "Copying /usr/local/texlive (this may take a while)…"
mkdir -p "${APPDIR}/usr/local"
cp -a /usr/local/texlive "${APPDIR}/usr/local/texlive"
# Copy system fonts (e.g. fonts-freefont-otf installed in the container)
echo "Copying system fonts…"
mkdir -p "${APPDIR}/usr/share/fonts"
if [[ -d /usr/share/fonts ]]; then
  cp -a /usr/share/fonts/. "${APPDIR}/usr/share/fonts/"
fi
# Copy fontconfig configuration including 09-texlive-fonts.conf
echo "Copying fontconfig config…"
mkdir -p "${APPDIR}/etc/fonts"
if [[ -d /etc/fonts ]]; then
  cp -a /etc/fonts/. "${APPDIR}/etc/fonts/"
fi
# fontconfig cache is generated at runtime by AppRun (per-user in ~/.cache/)
# because fonts.conf paths depend on the squashfs mount point which varies.
# Create .desktop file (required by appimagetool)
echo "Creating desktop entry…"
cat >"${APPDIR}/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=xelatex
Icon=${APP_NAME}
Categories=Office;
Terminal=true
EOF
# Minimal 1x1 PNG icon placeholder
printf '\x89PNG\r\n\x1a\n' >"${APPDIR}/${APP_NAME}.png"
echo "Creating AppRun…"
# TL_YEAR and TL_BIN_ARCH are baked in at build time.
cat >"${APPDIR}/AppRun" <<APPRUN_EOF
#!/usr/bin/env bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
CMD="\$(basename "\$0")"
TL_YEAR="${TL_YEAR}"
TL_BIN_ARCH="${TL_BIN_ARCH}"
TEXLIVE_ROOT="\${HERE}/usr/local/texlive/\${TL_YEAR}"
TL_BIN="\${TEXLIVE_ROOT}/bin/\${TL_BIN_ARCH}"
# kpathsea auto-computes TEXMFROOT via SELFAUTOPARENT from binary location,
# so we do NOT export TEXMFROOT/TEXMFCNF — that would confuse it.
# We only redirect TEXMFSYSVAR/TEXMFSYSCONFIG into the squashfs tree so
# that pre-built formats (.fmt) and updmap.cfg are found there.
# TEXMFVAR/TEXMFCONFIG remain writable user dirs (different from SYS ones
# so mktexfmt/fmtutil doesn't mistake user mode for sys mode).
export TEXMFSYSVAR="\${TEXLIVE_ROOT}/texmf-var"
export TEXMFSYSCONFIG="\${TEXLIVE_ROOT}/texmf-config"
export TEXMFHOME="\${HOME}/.texmf"
export TEXMFVAR="\${HOME}/.texlive\${TL_YEAR}/texmf-var"
export TEXMFCONFIG="\${HOME}/.texlive\${TL_YEAR}/texmf-config"
# fontconfig: generate a minimal fonts.conf pointing into the AppImage
# at runtime so all font paths are absolute and correct regardless of
# where the squashfs was mounted.
# The cache dir includes a hash of HERE so it is invalidated automatically
# when the squashfs mount point changes (e.g. with APPIMAGE_EXTRACT_AND_RUN).
_HERE_HASH="\$(printf '%s' "\${HERE}" |
md5sum | cut -c1-8)" # DevSkim: ignore DS126858
_FC_CACHE_DIR="\${HOME}/.cache/fontconfig-tl\${TL_YEAR}-\${_HERE_HASH}"
_FC_CONF="\${_FC_CACHE_DIR}/fonts.conf"
mkdir -p "\${_FC_CACHE_DIR}"
cat >"\${_FC_CONF}" <<FC_EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>\${HERE}/usr/share/fonts</dir>
  <dir>\${TEXLIVE_ROOT}/texmf-dist/fonts/opentype</dir>
  <dir>\${TEXLIVE_ROOT}/texmf-dist/fonts/truetype</dir>
  <dir>\${TEXLIVE_ROOT}/texmf-dist/fonts/type1</dir>
  <cachedir>\${_FC_CACHE_DIR}</cachedir>
  <include ignore_missing="yes">\${HERE}/etc/fonts/conf.d</include>
</fontconfig>
FC_EOF
export FONTCONFIG_FILE="\${_FC_CONF}"
# Warm up fontconfig cache before xelatex runs so polyglossia can detect
# Cyrillic script support in fonts on the very first invocation.
fc-cache -f "\${_FC_CONF}" 2>/dev/null || true
# luaotfload / XeTeX system font lookup inside the AppImage
export OSFONTDIR="\${HERE}/usr/share/fonts:\${TEXLIVE_ROOT}/texmf-dist/fonts"
export PATH="\${TL_BIN}:\${PATH}"
# Dispatch: symlink name → binary, first arg → binary, or default xelatex
if [[ "\${CMD}" != 'AppRun' ]] &&
  _B="\$(PATH="\${TL_BIN}" command -v "\${CMD}" 2>/dev/null)"; then
  exec "\${_B}" "\$@"
fi
if [[ \$# -gt 0 ]] &&
  _B="\$(PATH="\${TL_BIN}" command -v "\$1" 2>/dev/null)"; then
  _CMD="\$1"
  shift
  exec "\${_B}" "\$@"
fi
exec "\${TL_BIN}/xelatex" "\$@"
APPRUN_EOF
chmod +x "${APPDIR}/AppRun"
echo "Building AppImage…"
"${APPIMAGETOOL}" "${APPDIR}" "/tmp/${APP_NAME}.AppImage"
mkdir -p /output
cp "/tmp/${APP_NAME}.AppImage" /output/
echo "Build finished successfully!"
echo "  /output/${APP_NAME}.AppImage"
