#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='001'
  SHARED_ASSETS=(
    '_shared/install/coder.sh:_shared/install/coder.sh'
    '_shared/install/profile.sh:_shared/install/profile.sh'
    '_shared/sudoers:_shared/sudoers'
  )
}
stage_shared_assets
stage_profile "sources/${TAG}/_shared/profile-dmisu"
# shellcheck disable=2153
if [[ -z "${PUSHING:-}" ]]; then
  cat <<'EOF' >"sources/${TAG}/_shared/podman.sh"
#!/usr/bin/env bash
deb_link='http://deb.debian.org' # DevSkim: ignore DS137138
cat <<EOD >/etc/apt/sources.list.d/debian.sources
Types: deb
URIs: ${deb_link}/debian
Suites: trixie trixie-updates
Components: main contrib non-free
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp

Types: deb
URIs: ${deb_link}/debian-security
Suites: trixie-security
Components: main contrib non-free
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
EOD
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends podman netavark passt uidmap
EOF
  chmod 755 "sources/${TAG}/_shared/podman.sh"
fi
