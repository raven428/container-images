#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive

# Docker repository
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release
mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  >/etc/apt/sources.list.d/docker.list

# apt packages
apt-get update
apt-get install -y --no-install-recommends \
  build-essential \
  mingw-w64 \
  cmake \
  dpkg-dev \
  fakeroot \
  git \
  subversion \
  gh \
  jq \
  curl \
  wget \
  dnsutils \
  iputils-ping \
  inetutils-telnet \
  tnftp \
  net-tools \
  openssh-server \
  openssh-client \
  sudo \
  tini \
  tmux \
  vim \
  unzip \
  zip \
  bzip2 \
  gzip \
  patch \
  locales \
  language-pack-en \
  language-pack-en-base \
  language-pack-fr \
  language-pack-fr-base \
  upx-ucl \
  imagemagick \
  nodejs \
  npm \
  eslint \
  terser \
  webpack \
  ruby \
  rsyslog \
  systemd \
  nmon \
  python3 \
  python3-yaml \
  python3-requests \
  docker-ce-cli \
  docker-buildx-plugin \
  docker-compose-plugin
apt-get clean
rm -rf /var/lib/apt/lists/*

# locale
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen

# direct downloads
mkdir -vp /usr/local/bin

curl -fsSL "https://go.dev/dl/go1.25.5.linux-amd64.tar.gz" |
  tar -C /usr/local -xzf -

curl -fsSL \
  "https://github.com/tianon/gosu/releases/download/1.19/gosu-amd64" \
  -o /usr/local/bin/gosu

curl -fsSL https://www.lua.org/ftp/lua-5.5.0.tar.gz |
  tar -xzf - -C /tmp
make -C /tmp/lua-5.5.0 linux -j"$(nproc)"
install -m 0755 /tmp/lua-5.5.0/src/lua /usr/local/bin/lua
install -m 0755 /tmp/lua-5.5.0/src/luac /usr/local/bin/luac
rm -rf /tmp/lua-5.5.0

curl -fsSL \
  "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe" \
  -o /usr/local/bin/rcedit.exe

curl -fsSL \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o /tmp/awscli.zip
unzip -q /tmp/awscli.zip -d /tmp
/tmp/aws/install -i /usr/local/aws-cli -b /usr/local/bin
rm -rf /tmp/aws /tmp/awscli.zip

curl -fsSL \
  "https://github.com/weaveworks/eksctl/releases/download/v0.221.0/eksctl_Linux_amd64.tar.gz" |
  tar -xzf - -C /usr/local/bin eksctl

curl -fsSL \
  "https://get.helm.sh/helm-v3.19.4-linux-amd64.tar.gz" |
  tar -xzf - --strip-components=1 -C /usr/local/bin \
    "linux-amd64/helm"

curl -fsSL \
  "https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl" \
  -o /usr/local/bin/kubectl

curl -fsSL \
  "https://github.com/mikefarah/yq/releases/download/v4.50.1/yq_linux_amd64" \
  -o /usr/local/bin/yq

curl -fsSL \
  "https://github.com/dylanaraps/neofetch/archive/refs/tags/7.1.0.tar.gz" |
  tar -xzf - -C /tmp
install -m 0755 /tmp/neofetch-7.1.0/neofetch /usr/local/bin/neofetch
rm -rf /tmp/neofetch-7.1.0

cd /usr/local/bin
chmod -v 755 gosu rcedit.exe kubectl yq

# image configuration
mkdir -p /sources /builds /run /tmp
groupadd --gid 5001 dev
update-ca-certificates

# cleanup
rm -Rf /usr/share/doc /usr/share/man /files
