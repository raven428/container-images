#!/usr/bin/env bash
# cspell:ignore npmrc patchset
_npm_validate() {
  if [[ ! "${PATCHSET:-}" =~ ^(0|[1-9][0-9]*)$ ]]; then
    echo "invalid PATCHSET '${PATCHSET:-}': expected a non-negative integer" >&2
    return 66
  fi
  if [[ -z "${PUBLISH_MODE:-}" ]]; then
    echo 'PUBLISH_MODE must be set for npm sources' >&2
    return 66
  fi
  case "${PUBLISH_MODE}" in
  release | schedule | dev | skip) ;;
  *)
    echo "invalid PUBLISH_MODE '${PUBLISH_MODE}': expected \
release, schedule, dev, or skip" >&2
    return 66
    ;;
  esac
  if [[ -z "${VERSION_SUFFIX:-}" ]]; then
    echo 'VERSION_SUFFIX must be set for npm sources' >&2
    return 66
  fi
}
_npm_run() {
  local _tag="$1" _action="$2"
  shift 2
  local _auth_args=()
  if [[ "${_action}" == 'cont-publish.sh' ]]; then
    _auth_args=(-e NODE_AUTH_TOKEN)
  fi
  /usr/bin/env podman run --log-driver=none --rm --network host \
    -v "${PWD}:/workspace:z" \
    --workdir "/workspace/sources/${_tag}/_shared/upstream" \
    -e NPM_ARTIFACTS_DIR="/workspace/sources/${_tag}/_shared/npm-artifacts" \
    -e NPM_PACKAGE="${NPM_PACKAGE}" \
    -e NPM_REGISTRY="${NPM_REGISTRY}" \
    -e NPM_REPO_URL="${NPM_REPO_URL}" \
    -e PATCHSET="${PATCHSET}" \
    -e PUBLISH_MODE="${PUBLISH_MODE}" \
    -e UPSTREAM_VER="${UPSTREAM_VER}" \
    -e VERSION_SUFFIX="${VERSION_SUFFIX}" \
    "${_auth_args[@]+"${_auth_args[@]}"}" \
    "${NPM_IMAGE}" /usr/bin/env bash \
    "/workspace/_shared/npm/${_action}" "$@"
}
_npm_build() {
  local _tag="$1"
  shift
  _npm_validate
  local _artifacts_dir="sources/${_tag}/_shared/npm-artifacts"
  /usr/bin/env rm -rf "${_artifacts_dir}"
  /usr/bin/env mkdir -p "${_artifacts_dir}"
  _npm_run "${_tag}" 'cont-prepare.sh' "$@"
}
_npm_push() {
  local _tag="$1"
  _npm_validate
  if [[ "${PUBLISH_MODE}" == 'skip' ]]; then
    echo "skipping npm publish for [${_tag}]: PUBLISH_MODE=skip"
    return 0
  fi
  if [[ -z "${NODE_AUTH_TOKEN:-}" ]]; then
    echo 'NODE_AUTH_TOKEN must be set for npm publish' >&2
    return 66
  fi
  local _artifacts_dir="sources/${_tag}/_shared/npm-artifacts"
  local -a _expected=()
  case "${PUBLISH_MODE}" in
  release) _expected=(base.tgz release.tgz) ;;
  schedule) _expected=(release.tgz) ;;
  dev) _expected=(dev.tgz) ;;
  esac
  local _file
  for _file in "${_expected[@]}"; do
    if [[ ! -f "${_artifacts_dir}/${_file}" ]]; then
      echo "missing npm artifact '${_artifacts_dir}/${_file}'" >&2
      return 66
    fi
  done
  local -a _actual=()
  shopt -s nullglob
  _actual=("${_artifacts_dir}"/*)
  shopt -u nullglob
  if [[ ${#_actual[@]} -ne ${#_expected[@]} ]]; then
    echo "unexpected npm artifacts in '${_artifacts_dir}'" >&2
    return 66
  fi
  _npm_run "${_tag}" 'cont-publish.sh'
}
