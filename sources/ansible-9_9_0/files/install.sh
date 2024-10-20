#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y bash sudo ssh-client apt-utils python3-pip ca-certificates rsync
apt-get upgrade -y
pip install --upgrade pip
pip install -U -r files/requirements.txt
mv -vf /files/shared/sudoers /etc/sudoers
chmod 400 /etc/sudoers
mkdir -vp  /root/.config/yapf
mv -vf /files/style /root/.config/yapf/style
mv -vf /files/yamllint.yaml /root/.config/yamllint.yaml
mv -vf /files/check-syntax.sh /
chmod 755 /check-syntax.sh
mv -vf /files/shared/prepare2check.sh /

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
