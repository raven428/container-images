#!/usr/bin/env bash
set -uo pipefail
tmp_dir=''
orig_dir="${tmp_dir}/orig"
trim_dir="${tmp_dir}/trim"
# shellcheck source=/dev/null
source '/prepare2check.sh'
echo '1. extra EOLs and trailing whitespaces'
reset_trim_dir
for file in $(
  /usr/bin/env find "${trim_dir}" -type f -print |
    /usr/bin/env egrep -v '\.(png|pyc)$' |
    /usr/bin/env egrep -v '\/groundwork\/terragrunt\.hcl$'
); do
  remove_extra_eol "${file}"
done
for file in $(
  /usr/bin/env find "${trim_dir}" -type f -print |
    /usr/bin/env egrep '\.(sh|ya?ml|json|tf|hcl|py|md|conf|tfvars)$'
); do
  deny_tabs "${file}"
done
/usr/bin/env diff -ru --color=always "${orig_dir}" "${trim_dir}" ||
  addfail 'trimmed code'

echo '2. terraform formatting'
[[ -d "${TERRAFORM_DIR}" ]] && {
  reset_trim_dir
  /usr/bin/env terraform -chdir="${trim_dir}/${TERRAFORM_DIR}" fmt -recursive
  /usr/bin/env diff -ru --color=always "${orig_dir}/${TERRAFORM_DIR}" \
    "${trim_dir}/${TERRAFORM_DIR}" || addfail 'terraform fmt'
} || echo "skipped due to [TERRAFORM_DIR=${TERRAFORM_DIR}] isn't a directory"

echo '3. shfmt and shellcheck'
reset_trim_dir
for file in $(
  (
    # shellcheck disable=2016
    /usr/bin/env egrep -ri '^\#\!\/.+sh$' "${trim_dir}" |
      /usr/bin/env awk -F ':' '{print $1}' |
      /usr/bin/env egrep -v '\.j2$'
    /usr/bin/env shfmt -f "${trim_dir}"
  ) | /usr/bin/env sort | /usr/bin/env uniq
); do
  /usr/bin/env shfmt -i 2 -w "${file}"
  remove_extra_eol "${file}"
  /usr/bin/env shellcheck "${file}" ||
    addfail "shellcheck [${file}] failed"
done
/usr/bin/env diff -ru --color=always "${orig_dir}" "${trim_dir}" ||
  addfail 'shfmt'

echo '4. markdown lint'
reset_trim_dir
mapfile -t rules < <(
  # shellcheck disable=2016
  /usr/bin/env mdl -l |
    /usr/bin/env egrep '^MD.+' |
    /usr/bin/env egrep -v '^MD(007|013|022|029|032|033) ' |
    /usr/bin/env awk '{print $1}'
)
function join_by() {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}
for file in $(
  /usr/bin/env find "${trim_dir}" -iname '*.md' -type f -print
); do
  # shellcheck disable=2068
  /usr/bin/env mdl -r "$(join_by , ${rules[@]})" "${file}" ||
    addfail "markdown lint [${file}] failed"
done

echo '5. prettier YAML formatting'
reset_trim_dir
/usr/bin/env prettier \
  --loglevel warn --parser yaml -w "${trim_dir}"'/**/*.y*ml' &>/dev/stdout
/usr/bin/env diff -ru --color=always "${orig_dir}" "${trim_dir}" ||
  addfail 'prettier-yaml'

echo '6. prettier markdown formatting'
reset_trim_dir
/usr/bin/env prettier \
  --loglevel warn --parser markdown -w "${trim_dir}"'/**/*.md' &>/dev/stdout
/usr/bin/env diff -ru --color=always "${orig_dir}" "${trim_dir}" ||
  addfail 'prettier-markdown'

echo "7. prometheus rules test"
if [[ -d "${PROM_RULES_DIR}" ]]; then
  (
    cd "${PROM_RULES_DIR}" || true
    # shellcheck disable=2046
    /usr/bin/env promtool test rules $(
      /usr/bin/env find -iname '*.y*ml' -type f -print |
        /usr/bin/env sort -V
    ) &>/dev/stdout || addfail 'prometheus rules'
  )
else
  echo "skipped due to [PROM_RULES_DIR=${PROM_RULES_DIR}] isn't a directory"
fi

cleanup 'done'
