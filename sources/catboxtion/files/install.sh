#!/usr/bin/env bash
# cspell:ignore playwmcp catbox nologin permitlisten
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
# apt-get update
# apt-get install -y --no-install-recommends sshd
users2add=(
  'playwmcp:AAAAC3NzaC1lZDI1NTE5AAAAIFcvxd7wbPuW+iCLv3NSnp+zuRkTbkQcfTvRwlT1ITOy'
  'librechat:AAAAC3NzaC1lZDI1NTE5AAAAINO5ck1krbI5s7cD7NdMZIzYuiBXVrmIAk8Noncb3OoV'
)
idx=1
for entry in "${users2add[@]}"; do
  username=${entry%%:*}
  login=$(printf 'cb%03d-%s' "${idx}" "${username}")
  uid=$(printf '22%03d' "${idx}")
  addr='127.0.0.1' # DevSkim: ignore DS162092
  pubkey="permitlisten=\"${addr}:${uid}\" ssh-ed25519 ${entry##*:} ${username}"
  home=/catbox/${login}
  useradd -u "${uid}" -s /sbin/nologin -d "${home}" -c "${login}" "${login}"
  install -d -m 700 -o "${login}" "${home}/.ssh"
  printf '%s\n' "${pubkey}" |
    install -m 600 -o "${login}" /dev/stdin "${home}/.ssh/authorized_keys"
  ((idx++))
done
cat <<EOF >/etc/ssh/sshd_config.d/defaults.conf
Port 10022
AddressFamily inet
ListenAddress 127.0.0.1 # DevSkim: ignore DS162092
ClientAliveCountMax 3
ClientAliveInterval 11
EOF
# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
