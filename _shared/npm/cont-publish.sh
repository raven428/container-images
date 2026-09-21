#!/usr/bin/env bash
# cspell:ignore patchset
set -ueo pipefail
_read_package() {
  local _archive="$1" _metadata _name _version
  # shellcheck disable=SC2016
  _metadata="$(/usr/bin/env tar -xOf "${NPM_ARTIFACTS_DIR}/${_archive}" \
    package/package.json | /usr/bin/env node -e '
let input = "";
process.stdin.on("data", (chunk) => { input += chunk; });
process.stdin.on("end", () => {
  const pkg = JSON.parse(input);
  if (typeof pkg.name !== "string" || !pkg.name ||
      typeof pkg.version !== "string" || !pkg.version) process.exit(66);
  process.stdout.write(`${pkg.name}\t${pkg.version}`);
});')"
  IFS=$'\t' read -r _name _version <<<"${_metadata}"
  if [[ "${_name}" != "${NPM_PACKAGE}" ]]; then
    echo "unexpected npm package '${_name}' in ${_archive}" >&2
    return 66
  fi
  printf '%s\t%s\n' "${_name}" "${_version}"
}
_publish() {
  local _archive="$1" _tag="$2" _name="$3" _version="$4"
  echo "publishing ${_name}@${_version} with dist-tag ${_tag}"
  if /usr/bin/env npm publish "${NPM_ARTIFACTS_DIR}/${_archive}" \
    --registry "${NPM_REGISTRY}" --ignore-scripts --tag "${_tag}"; then
    return 0
  fi
  echo "failed to publish ${_name}@${_version}" >&2
  return 1
}
_base="${UPSTREAM_VER#v}-p${PATCHSET}"
case "${PUBLISH_MODE}" in
release)
  _base_metadata="$(_read_package 'base.tgz')"
  IFS=$'\t' read -r _name _version <<<"${_base_metadata}"
  if [[ "${_version}" != "${_base}" ]]; then
    echo "unexpected base version '${_version}'" >&2
    exit 66
  fi
  umask 077
  /usr/bin/env printf '//npm.pkg.github.com/:_authToken=%s\n' \
    "${NODE_AUTH_TOKEN}" >"${HOME}/.npmrc"
  echo "publishing ${_name}@${_version} with dist-tag latest"
  if /usr/bin/env npm publish "${NPM_ARTIFACTS_DIR}/base.tgz" \
    --registry "${NPM_REGISTRY}" --ignore-scripts --tag latest; then
    exit 0
  fi
  echo "base publish failed; falling back to dated release" >&2
  _release_metadata="$(_read_package 'release.tgz')"
  IFS=$'\t' read -r _name _version <<<"${_release_metadata}"
  if [[ ! "${_version}" =~ ^${_base}-([0-9]{8})- ]] ||
    [[ "${_version}" != "${_base}-${BASH_REMATCH[1]}-${VERSION_SUFFIX}" ]]; then
    echo "unexpected release version '${_version}'" >&2
    exit 66
  fi
  _publish 'release.tgz' latest "${_name}" "${_version}"
  ;;
schedule)
  _release_metadata="$(_read_package 'release.tgz')"
  IFS=$'\t' read -r _name _version <<<"${_release_metadata}"
  if [[ ! "${_version}" =~ ^${_base}-([0-9]{8})- ]] ||
    [[ "${_version}" != "${_base}-${BASH_REMATCH[1]}-${VERSION_SUFFIX}" ]]; then
    echo "unexpected release version '${_version}'" >&2
    exit 66
  fi
  umask 077
  /usr/bin/env printf '//npm.pkg.github.com/:_authToken=%s\n' \
    "${NODE_AUTH_TOKEN}" >"${HOME}/.npmrc"
  _publish 'release.tgz' latest "${_name}" "${_version}"
  ;;
dev)
  _dev_metadata="$(_read_package 'dev.tgz')"
  IFS=$'\t' read -r _name _version <<<"${_dev_metadata}"
  if [[ "${_version}" != "${_base}-dev.${VERSION_SUFFIX}" ]]; then
    echo "unexpected dev version '${_version}'" >&2
    exit 66
  fi
  umask 077
  /usr/bin/env printf '//npm.pkg.github.com/:_authToken=%s\n' \
    "${NODE_AUTH_TOKEN}" >"${HOME}/.npmrc"
  _publish 'dev.tgz' dev "${_name}" "${_version}"
  ;;
*)
  echo "invalid PUBLISH_MODE '${PUBLISH_MODE}'" >&2
  exit 66
  ;;
esac
