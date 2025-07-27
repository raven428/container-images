#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='000'
  DEPENDS='ansible-ubuntu/ ansible-builder/'
}
/usr/bin/env cp -rf _shared "sources/${TAG}"
/usr/bin/env cp -fv _shared/install/ansible/Dockerfile "sources/${TAG}"
/usr/bin/env cp -fv _shared/install/ansible/* "sources/${TAG}/files/"
/usr/bin/env sed -i 's|^\(.*patch -p0 </files/flush-line.diff.*\)|# \1|' \
  "sources/${TAG}/files/build.sh"
echo 'patch -p0 </files/async-check.diff' >>"sources/${TAG}/files/build.sh"
/usr/bin/env cat "sources/${TAG}/files/async-check.diff" |
  /usr/bin/env awk \
    '/^--- .+site-packages\/ansible\/plugins\/action\/__init__/ { exit } { print }' |
  /usr/bin/env sed -rz \
    's/\x0d\x0a/\x0a/g; s/\x0d/\x0a/g; s/[ \t]+\x0a/\x0a/g; s/\x0a*$/\x0a/g' \
    >"sources/${TAG}/files/async-check-new.diff"
/usr/bin/env mv -fv "sources/${TAG}/files/async-check-new.diff" \
  "sources/${TAG}/files/async-check.diff"
cat <<EOF >>"sources/${TAG}/files/build.sh"
/usr/bin/env sed -ri '/^\s+elif self._task.async_val and self\..+$/d;
/^.+check mode and async cannot be used on same task.+$/d' \
lib/python3.11/site-packages/ansible/plugins/action/__init__.py
EOF
