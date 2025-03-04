#!/usr/bin/env bash
set -uo pipefail
return_code=0
/usr/bin/env mkdir -vp "${HOME}/temp"
if ! tmp_dir=$(/usr/bin/env mktemp -d "${HOME}/temp/chesyXXXXX"); then
  echo 'unable to create temporary directory, bye…'
  exit 66
fi
trap_with_arg() {
  func="$1"
  shift
  for sig; do
    # shellcheck disable=2064
    trap "${func} ${sig}" "${sig}"
  done
}
cleanup() {
  /usr/bin/env rm -rf "${tmp_dir}"
  trap - INT QUIT ABRT KILL TERM STOP
  if [[ "$1" != 'done' ]]; then
    return_code=1
  fi
  echo "signal [$1] code [${return_code}] finished"
  exit ${return_code}
}
addfail() {
  subject="${1:-none}"
  return_code=$((return_code + 1))
  echo "check 👆 with ${subject}, fails count=${return_code}"
}
reset_trim_dir() {
  # echo -n "resetting [${trim_dir}] from [${orig_dir}]… "
  /usr/bin/env rsync \
    -caHAX \
    --force \
    --delete \
    "${orig_dir}/." "${trim_dir}/."
  # echo "done!"
}
remove_extra_eol() {
  file="$1"
  shift
  # - transform DOS EOLs to "\n"
  # - transform Mac EOLs to "\n"
  # - trim trailing whitespaces
  # - replace multiple final newlines to single
  /usr/bin/env sed -rzi '
  s/\x0d\x0a/\x0a/g ;
  s/\x0d/\x0a/g ;
  s/[ \t]+\x0a/\x0a/g ;
  s/\x0a*$/\x0a/g
  ' "${file}"
}
deny_tabs() {
  file="$1"
  shift
  /usr/bin/env sed -rzi 's/\t/ tabs denied /g' "${file}"
}
trap_with_arg cleanup INT QUIT ABRT KILL TERM STOP

orig_dir="${tmp_dir}/orig"
trim_dir="${tmp_dir}/trim"
echo -n "rsync to [${tmp_dir}] for checking… "
/usr/bin/env rsync \
  -caHAX \
  --force \
  --delete \
  --no-perms \
  --chmod=u=rwX,g=,o= \
  --delete-excluded \
  --exclude='/.git' \
  --exclude='/secure' \
  --exclude='/**/.terraform' \
  --exclude='/**/.terragrunt-cache' \
  --exclude='/ansible/roles/external' \
  "$(readlink -f .)/." "${orig_dir}"
for f in $(
  /usr/bin/env find \
    "${orig_dir}" \
    -path '*prom*/*.rules' -print
); do
  /usr/bin/env ln -sf "$(basename "${f}")" "${f%.*}.yaml"
done
/usr/bin/env mkdir "${trim_dir}"
echo "done!"
