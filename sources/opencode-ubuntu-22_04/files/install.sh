#!/usr/bin/env bash
set -ueo pipefail

# generic packages
apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  bash apt-utils apt-file ca-certificates ethtool bash-completion dstat tcpdump less \
  vim tmux screen curl wget rsync xz-utils pixz nmap atop htop traceroute sudo \
  whois iotop netcat telnet bind9-utils bind9-host bind9-dnsutils gdisk p7zip \
  iftop nmon reptyr psmisc jq git bc lsof progress pv tree iproute2 net-tools \
  hostname dmidecode groff-base hdparm lshw iputils-ping iputils-arping locales \
  secure-delete moreutils less acl lz4 lzop lzma zstd unzip mtr patch ripgrep file \
  binutils bsdextrautils openssh-client
cat >/etc/locale.gen <<'EOF'
en_US.UTF-8 UTF-8
en_GB.UTF-8 UTF-8
EOF
locale-gen

# direct download
mkdir -vp /usr/local/bin
cd /usr/local/bin
curl -sLo kubectl "https://dl.k8s.io/release/$(curl -L -s \
  https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -sLo yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
curl -sLo opencode "https://github.com/raven428/opencode-ctrl/releases/\
download/v1.2.16p1/opencode-v1_2_16-linux-x64"
chmod -v 755 opencode kubectl yq
curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -sL "https://github.com/fullstorydev/grpcurl/releases/download/v1.9.1/grpcurl\
_1.9.1_linux_amd64.deb" -o /files/grpcurl.deb && dpkg -i /files/grpcurl.deb

# image configuration
rm -Rf /root
mv -v /files/shared/profile-dmisu /root
# shellcheck disable=2016
find /root -type d -print0 | xargs chmod 755
find /root -type f -print0 | xargs chmod 644
update-ca-certificates
mv -vf /files/shared/sudoers /etc/sudoers
chmod 400 /etc/sudoers

# cleanup
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
