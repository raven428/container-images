#!/usr/bin/env bash
set -ueo pipefail

# generic packages
apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get install -y \
  bash apt-utils apt-file ca-certificates ethtool bash-completion dstat tcpdump \
  vim tmux screen curl wget rsync xz-utils pixz nmap atop htop traceroute sudo \
  whois iotop netcat telnet bind9-utils bind9-host bind9-dnsutils gdisk p7zip \
  iftop nmon reptyr psmisc jq git bc lsof progress pv tree iproute2 net-tools \
  hostname dmidecode groff-base hdparm lshw iputils-ping iputils-arping locales \
  secure-delete moreutils less acl lz4 lzop lzma zstd unzip redis-tools \
  mysqltuner mariadb-client postgresql-client
apt-get upgrade -y

# https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
  tee /etc/apt/trusted.gpg.d/microsoft.asc
curl -sL https://packages.microsoft.com/config/ubuntu/22.04/prod.list |
  tee /etc/apt/sources.list.d/mssql-release.list
apt-get update
export ACCEPT_EULA=Y
apt-get install -y mssql-tools18 unixodbc-dev

# https://www.mongodb.com/docs/mongocli/current/install/
curl -sL https://www.mongodb.org/static/pgp/server-6.0.asc |
  tee /etc/apt/trusted.gpg.d/mongo.asc
echo "deb [ arch=amd64,arm64 ] \
  https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" |
  tee /etc/apt/sources.list.d/mongodb-org-6.0.list
apt-get update
apt-get install -y mongodb-org-shell
apt-get clean

# direct download
mkdir -vp /usr/local/bin
curl -sL "https://dl.k8s.io/release/$(curl -L -s \
  https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
  -o /usr/local/bin/kubectl
curl -sL \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
  -o /usr/local/bin/yq
curl -sL \
  https://raw.githubusercontent.com/jfcoz/postgresqltuner/master/postgresqltuner.pl \
  -o /usr/local/bin/postgresqltuner.pl
cd /usr/local/bin
chmod -v 755 kubectl yq postgresqltuner.pl
curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# image configuration
update-ca-certificates
rm -Rfv /root
mv -v /files/shared/profile-dmisu /root
# shellcheck disable=2016
echo 'PATH="${PATH}:/opt/mssql-tools18/bin"' >> ~/.bashrc_local
find /root -type d -print0 | xargs chmod 755
find /root -type f -print0 | xargs chmod 644
mv -vf /files/sudoers /etc/sudoers
chmod 400 /etc/sudoers
echo 'en_US.UTF-8 UTF-8' >/etc/locale.gen
locale-gen

# cleanup
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
