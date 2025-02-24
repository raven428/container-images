#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y bash apt-utils shellcheck nodejs shfmt ruby nodejs curl \
  gnupg xz-utils rsync vim
apt-get upgrade -y

# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
curl -sL https://apt.releases.hashicorp.com/gpg |
  gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com jammy main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

# direct downloads
gem install mdl
(
  cd /files
  curl -sLOm 11 \
    https://github.com/raven428/container-images/releases/download/000/prettier-2_5_1.tar.xz
  mkdir -vp /usr/local/node
  cd /usr/local/node
  tar xf /files/prettier-2_5_1.tar.xz
  ln -sf /usr/local/node/prettier/bin-prettier.js /usr/local/bin/prettier
  cd /files
  prom_ver='2.54.1.linux-amd64'
  curl -sLOm 222 \
    "https://github.com/prometheus/prometheus/releases/download/v2.54.1/prometheus-${prom_ver}.tar.gz"
  tar xf "prometheus-${prom_ver}.tar.gz"
  mv -vf prometheus-${prom_ver}/promtool /usr/local/bin/promtool
  chmod -v 755 /usr/local/bin/promtool
)

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
