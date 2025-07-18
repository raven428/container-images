#!/usr/bin/env bash
set -ueo pipefail
mv -vf /files/shared/sudoers /etc/sudoers
chmod 400 /etc/sudoers
# shellcheck disable=1091
source /etc/environment
sed -ri "s|PATH\s*=.+$|PATH='/ansbl:${PATH}'|g" /etc/environment
ln -sfv "${PYENV_ROOT}/versions/ansible/bin" '/ansbl'
sed -i '/^auth[[:space:]]\+sufficient[[:space:]]\+pam_rootok\.so$/a\account sufficient pam_succeed_if.so uid = 0 use_uid quiet' /etc/pam.d/su
mkdir -vp /root/.config/yapf
mv -vf /files/style /root/.config/yapf/style
mv -vf /files/yamllint.yaml /root/.config/yamllint.yaml
mv -vf /files/ansible-lint.yaml /root/.config/ansible-lint.yaml
mv -vf /files/check-syntax.sh /
chmod 755 /check-syntax.sh
mv -vf /files/shared/prepare2check.sh /
mkdir -vp /ansible

# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
