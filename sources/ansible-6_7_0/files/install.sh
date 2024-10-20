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

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
