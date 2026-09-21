#!/usr/bin/env bash
# cspell:ignore patchset
set -ueo pipefail
_pack() {
  local _target="$1" _packed
  _packed="$(/usr/bin/env npm pack --ignore-scripts --json | /usr/bin/env node -e '
let input = "";
process.stdin.on("data", (chunk) => { input += chunk; });
process.stdin.on("end", () => {
  const packs = JSON.parse(input);
  if (packs.length !== 1 || typeof packs[0].filename !== "string") process.exit(66);
  process.stdout.write(packs[0].filename);
});')"
  /usr/bin/env mv "${_packed}" "${NPM_ARTIFACTS_DIR}/${_target}"
}
_base="${UPSTREAM_VER#v}-p${PATCHSET}"
_utc_date="$(/usr/bin/env date -u '+%Y%m%d')"
_dated="${_base}-${_utc_date}-${VERSION_SUFFIX}"
_dev="${_base}-dev.${VERSION_SUFFIX}"
case "${PUBLISH_MODE}" in
release | schedule | skip) _compile_version="${_base}" ;;
dev) _compile_version="${_dev}" ;;
*)
  echo "invalid PUBLISH_MODE '${PUBLISH_MODE}'" >&2
  exit 66
  ;;
esac
/usr/bin/env npm pkg set "name=${NPM_PACKAGE}" "version=${_compile_version}" \
  'repository.type=git' "repository.url=${NPM_REPO_URL}" \
  "publishConfig.registry=${NPM_REGISTRY}"
/usr/bin/env npm ci --include=dev
for _check in "$@"; do
  echo "running npm check: ${_check}"
  /usr/bin/env bash -ueo pipefail -c "${_check}"
done
/usr/bin/env npm run build
case "${PUBLISH_MODE}" in
release)
  _pack 'base.tgz'
  /usr/bin/env npm pkg set "version=${_dated}"
  _pack 'release.tgz'
  /usr/bin/env npm pkg set "version=${_base}"
  ;;
schedule)
  /usr/bin/env npm pkg set "version=${_dated}"
  _pack 'release.tgz'
  /usr/bin/env npm pkg set "version=${_base}"
  ;;
dev) _pack 'dev.tgz' ;;
skip) ;;
esac
