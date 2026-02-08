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
  secure-delete moreutils less acl lz4 lzop lzma zstd unzip mtr patch
cat >/etc/locale.gen <<'EOF'
en_US.UTF-8 UTF-8
en_GB.UTF-8 UTF-8
EOF
locale-gen
apt-get upgrade -y
curl -fsSL https://deb.nodesource.com/setup_22.x | bash
apt-get install -y --no-install-recommends nodejs

# direct download
mkdir -vp /usr/local/bin
cd /usr/local/bin
curl -sL "https://dl.k8s.io/release/$(curl -L -s \
  https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o kubectl
curl -sL \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq
cat >/usr/local/bin/opencode <<'EOF'
#!/usr/bin/env bash
/root/.bun/bin/bun run --cwd /usr/local/bun/packages/opencode \
  --conditions=browser src/index.ts $@
EOF
chmod -v 755 opencode kubectl yq
curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -sL "https://github.com/fullstorydev/grpcurl/releases/download/v1.9.1/grpcurl\
_1.9.1_linux_amd64.deb" -o /files/grpcurl.deb && dpkg -i /files/grpcurl.deb

# opencode
rm -Rfv /root
mv -v /files/shared/profile-dmisu /root
# shellcheck disable=2016
find /root -type d -print0 | xargs chmod 755
find /root -type f -print0 | xargs chmod 644
cd /root
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"
rm -vf .gitconfig
git clone https://github.com/anomalyco/opencode.git
git reset --hard HEAD
mkdir -vp /usr/local/bun
(cd opencode && git checkout "v${OPENCODE_VERSION}" && patch -p1 </files/opencode.diff &&
  patch -p1 </files/version.diff && mv -v package.json packages /usr/local/bun)
bun install --production --cwd /usr/local husky
ln -sfv /usr/local/node_modules/husky/bin.js /usr/local/bin/husky
bun install --production --cwd /usr/local/bun
bun pm cache rm --cwd /usr/local/bun
(cd /usr/local/bun/node_modules/.bun && rm -rf /root/.bun/install/cache /root/opencode \
  '@ibm+plex@6.4.1/node_modules/@ibm/plex/IBM-Plex-Sans-JP' \
  '@ibm+plex@6.4.1/node_modules/@ibm/plex/IBM-Plex-Sans-KR' \
  '@cloudflare+workerd-linux-64@1.20251118.0/node_modules/@cloudflare/workerd-linux-64')

# image configuration
update-ca-certificates
mkdir -vp /root/.bun/install/cache
mv -vf /files/shared/sudoers /etc/sudoers
chmod 400 /etc/sudoers

# cleanup
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
