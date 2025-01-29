#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y bash sudo ssh-client apt-utils python3-venv ca-certificates \
  rsync podman
apt-get upgrade -y
python3 -m venv /venv
pip install --upgrade pip
pip install -U -r files/requirements.txt
mv -vf /files/shared/sudoers /etc/sudoers
chmod 400 /etc/sudoers
# shellcheck disable=1091
source /etc/environment
echo "PATH=\"/venv/bin:${PATH}\"" >>/etc/environment
sed -i '/^auth[[:space:]]\+sufficient[[:space:]]\+pam_rootok\.so$/a\account sufficient pam_succeed_if.so uid = 0 use_uid quiet' /etc/pam.d/su
mkdir -vp  /root/.config/yapf
mv -vf /files/style /root/.config/yapf/style
mv -vf /files/yamllint.yaml /root/.config/yamllint.yaml
mv -vf /files/check-syntax.sh /
chmod 755 /check-syntax.sh
mv -vf /files/shared/prepare2check.sh /

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
