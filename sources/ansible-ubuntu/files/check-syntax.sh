#!/usr/bin/env bash
set -uo pipefail
tmp_dir=''
orig_dir="${tmp_dir}/orig"
trim_dir="${tmp_dir}/trim"
# shellcheck source=/dev/null
source '/prepare2check.sh'
echo '1. yapf formatting'
reset_trim_dir
for file in $(
  /usr/bin/env find "${trim_dir}" -iname '*.py' -type f -print
); do
  /usr/bin/env yapf -i "${file}"
done
/usr/bin/env diff -ru --color=always "${orig_dir}" "${trim_dir}" ||
  addfail 'yapf'

echo '2. yamllint'
reset_trim_dir
yamllint -c /root/.config/yamllint.yaml -f colored "${trim_dir}" ||
  addfail 'yamllint'

echo '3. ansible-lint'
reset_trim_dir
/usr/bin/env ansible-lint \
  --exclude ansible/roles/external \
  --force-color -x 106 "${ANSIBLENTRY:-ansible/site.yaml}" &>/dev/stdout ||
  addfail 'ansible-lint'

cleanup 'done'
