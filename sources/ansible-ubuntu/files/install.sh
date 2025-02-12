#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND='noninteractive'
apt-get update
find_package() {
  apt-cache search --names-only "$1" 2>/dev/null |
    awk '{print $1}'
}
apt-get install -y bash sudo ssh-client apt-utils ca-certificates rsync podman \
  "$(find_package '^libreadline[_\.0-9\-]+$')" \
  "$(find_package '^libsqlite[_\.0-9\-]+$')" \
  "$(find_package '^libbz[_\.0-9\-]+$')" \
  "$(find_package '^zlib[\.0-9\-]+[a-z]$')" \
  "$(find_package '^libssl[0-9]')" \
  "$(find_package '^libffi[0-9]+$')" \
  "$(find_package '^liblzma[0-9]+$')"
mv -vf /files/shared/sudoers /etc/sudoers
chmod 400 /etc/sudoers
# shellcheck disable=1091
source /etc/environment
echo "PATH=\"/ansbl:${PATH}\"" >>/etc/environment
ln -sfv "${PYENV_ROOT}/versions/ansible/bin" '/ansbl'
sed -i '/^auth[[:space:]]\+sufficient[[:space:]]\+pam_rootok\.so$/a\account sufficient pam_succeed_if.so uid = 0 use_uid quiet' /etc/pam.d/su
mkdir -vp  /root/.config/yapf
mv -vf /files/style /root/.config/yapf/style
mv -vf /files/yamllint.yaml /root/.config/yamllint.yaml
mv -vf /files/check-syntax.sh /
chmod 755 /check-syntax.sh
mv -vf /files/shared/prepare2check.sh /

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip
