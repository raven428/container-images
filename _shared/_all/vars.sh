#!/usr/bin/env bash
set -ueo pipefail
: "${TARGET_REGISTRY:=ghcr.io/raven428}"
: "${NPM_REGISTRY:=https://npm.pkg.github.com}"
: "${NPM_IMAGE:=ghcr.io/raven428/node-builder:latest}"
: "${NPM_REPO_URL:=git+https://github.com/raven428/container-images.git}"
_validate_version_suffix() {
  local _suffix="$1"
  if [[ ! "${_suffix}" =~ ^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$ ]]; then
    echo "invalid VERSION_SUFFIX '${_suffix}': expected dot-separated ASCII" \
      'letters, digits, or hyphens' >&2
    return 66
  fi
  local -a _identifiers
  local _identifier
  IFS='.' read -r -a _identifiers <<<"${_suffix}"
  for _identifier in "${_identifiers[@]}"; do
    if [[ "${_identifier}" =~ ^[0-9]+$ && "${_identifier}" == 0* &&
      "${_identifier}" != '0' ]]; then
      echo "invalid VERSION_SUFFIX '${_suffix}': numeric identifier" \
        "'${_identifier}' has a leading zero" >&2
      return 66
    fi
  done
}
DEV_TAG=''
if [[ -z "${PUBLISH_MODE:-}" && -z "${VERSION_SUFFIX:-}" ]]; then
  :
elif [[ -z "${PUBLISH_MODE:-}" || -z "${VERSION_SUFFIX:-}" ]]; then
  echo 'PUBLISH_MODE and VERSION_SUFFIX must both be set or both be empty:' \
    "PUBLISH_MODE='${PUBLISH_MODE:-}', VERSION_SUFFIX='${VERSION_SUFFIX:-}'" >&2
  (exit 66)
else
  _validate_version_suffix "${VERSION_SUFFIX}"
  case "${PUBLISH_MODE}" in
  dev | skip)
    DEV_TAG="dev.${VERSION_SUFFIX}"
    ;;
  release | schedule) ;;
  *)
    echo "invalid PUBLISH_MODE '${PUBLISH_MODE}': expected release, schedule," \
      'dev, or skip' >&2
    (exit 66)
    ;;
  esac
fi
_set_dev_tag_args() {
  local -n _dev_tag_args="$1"
  _dev_tag_args=()
  if [[ -n "${DEV_TAG}" ]]; then
    _dev_tag_args=("${TARGET_REGISTRY}/${TAG}:${DEV_TAG}")
  fi
}
# MANUAL_IMAGES_DIRS='docker-alpine/ systemd-ubuntu-22_04/' ./build.sh for manual build
: "${MANUAL_IMAGES_DIRS:=}"
/usr/bin/env printf "\n———⟨ environment: ⟩———\n"
set
/usr/bin/env which git >/dev/null ||
  if /usr/bin/env fgrep debian /etc/os-release; then
    export DEBIAN_FRONTEND=noninteractive
    /usr/bin/env apt-get update && /usr/bin/env apt-get install -y \
      --no-install-recommends git
  else
    /usr/bin/env apk update && /usr/bin/env apk add git
  fi

# Resolve diff lines for the current event. Honors MANUAL_DIFF for local runs.
_diff_lines() {
  if [[ -n "${MANUAL_DIFF:-}" ]]; then
    /usr/bin/env printf '%s\n' "${MANUAL_DIFF}"
    return
  fi
  local _before
  case "${GITHUB_EVENT_NAME:-${CI_PIPELINE_SOURCE:-}}" in
  push)
    _before="${GITHUB_EVENT_BEFORE:-${CI_COMMIT_BEFORE_SHA:-}}"
    # null SHA means first push to branch or force-push; fall back to HEAD^1
    if [[ -z "${_before}" ]] || [[ "${_before}" =~ ^0+$ ]]; then
      _before='HEAD^1'
    fi
    /usr/bin/env git diff --name-only \
      "${_before}" "${GITHUB_SHA:-${CI_COMMIT_SHA:-HEAD}}" 2>/dev/null || true
    ;;
  pull_request)
    /usr/bin/env git diff --name-only \
      "remotes/origin/${GITHUB_BASE_REF:-master}"...HEAD 2>/dev/null || true
    ;;
  merge_request_event)
    /usr/bin/env git diff --name-only \
      "remotes/origin/${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME}" \
      "remotes/origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}" 2>/dev/null || true
    ;;
  *)
    # local invocation: compare working tree to HEAD
    /usr/bin/env git diff --name-only HEAD 2>/dev/null || true
    ;;
  esac
}

# Fill IMAGES_DIRS with every directory under sources/.
_fill_all_images() {
  IMAGES_DIRS=()
  for _dir in sources/*/; do
    [[ -d "${_dir}" ]] && IMAGES_DIRS+=("${_dir%/}")
  done
}

# Source a vars.sh in an isolated copy while retaining errors from the source.
_probe_vars() {
  local _image="$1" _field="$2" _probe
  _probe="$(/usr/bin/env mktemp -d -t 'container-images-vars-XXXXXX')"
  # shellcheck disable=SC2064
  trap "/usr/bin/env rm -rf '${_probe}'" EXIT
  /usr/bin/env mkdir -p "${_probe}/bin" "${_probe}/sources"
  /usr/bin/env cp -a "${_image}" "${_probe}/sources/"
  /usr/bin/env printf '#!/usr/bin/env bash\nexit 0\n' >"${_probe}/bin/cp"
  /usr/bin/env chmod +x "${_probe}/bin/cp"
  (
    cd "${_probe}"
    PATH="${_probe}/bin:${PATH}"
    eval "$(_build_vars_shunts "${_image}/vars.sh")"
    # shellcheck disable=2034
    TAG="${_image#sources/}"
    # shellcheck disable=2034
    IMAGE_DIR="${_image}"
    # shellcheck disable=2034
    PUSHING=1
    # shellcheck disable=2034
    NPM_PACKAGE=''
    SHARED_ASSETS=()
    # shellcheck disable=SC1091,SC1090
    source "${_image}/vars.sh" >/dev/null
    case "${_field}" in
    package) /usr/bin/env printf '%s' "${NPM_PACKAGE}" ;;
    assets) /usr/bin/env printf '%s\n' "${SHARED_ASSETS[@]:-}" ;;
    esac
  )
}
# Add every npm source to the associative array named by the first argument.
_pick_npm_sources() {
  local -n _picked="$1"
  local _dir _image _package
  for _dir in sources/*/; do
    [[ -f "${_dir}vars.sh" ]] || continue
    _image="${_dir%/}"
    _package="$(_probe_vars "${_image}" package)"
    [[ -n "${_package}" ]] && _picked["${_image}"]=1
  done
  return 0
}

MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${MY_PATH}/../vars.sh"

if [[ "${MANUAL_IMAGES_DIRS}" != '' ]]; then
  IMAGES_DIRS=()
  for dir in ${MANUAL_IMAGES_DIRS}; do
    while [[ "${dir}" == */ ]]; do dir="${dir%/}"; done
    IMAGES_DIRS+=("sources/${dir}")
  done
elif [[ "${GITHUB_EVENT_NAME:-${CI_PIPELINE_SOURCE:-}}" == 'schedule' ]]; then
  # cron: rebuild everything, no diff needed
  _fill_all_images
else
  diff="$(_diff_lines)"
  /usr/bin/env printf "\n———⟨ diff: ⟩———\n\
%s\n\n———⟨ images: ⟩———\n" "${diff}"
  # empty diff (e.g. initial push with null before-sha, or nothing outside
  # sources/) — fall back to rebuilding everything, matching old behavior
  if [[ -z "${diff//[[:space:]]/}" ]]; then
    _fill_all_images
  elif /usr/bin/env printf '%s\n' "${diff}" |
    /usr/bin/env grep -qE '^(_shared/_all/|_shared/vars\.sh$)'; then
    # framework-level change: rebuild everything
    _fill_all_images
  else
    declare -A picked=()
    # direct hits under sources/<image>/
    while IFS= read -r _line; do
      [[ -z "${_line}" ]] && continue
      if [[ "${_line}" =~ ^sources/([^/]+)/ ]]; then
        picked["sources/${BASH_REMATCH[1]}"]=1
      fi
    done <<<"${diff}"
    if /usr/bin/env printf '%s\n' "${diff}" | /usr/bin/env grep -qE '^_shared/npm/'; then
      _pick_npm_sources picked
    fi
    # transitive hits via SHARED_ASSETS: source each vars.sh in a subshell
    # with side-effect commands neutralized via _build_vars_shunts
    for _dir in sources/*/; do
      [[ -f "${_dir}vars.sh" ]] || continue
      _image="${_dir%/}"
      [[ -n "${picked[${_image}]:-}" ]] && continue
      _assets="$(_probe_vars "${_image}" assets)"
      [[ -z "${_assets}" ]] && continue
      _hit=0
      while IFS= read -r _entry; do
        [[ -z "${_entry}" ]] && continue
        _entry_src="${_entry%%:*}"
        _entry_src="${_entry_src#./}"
        while IFS= read -r _expanded; do
          [[ -z "${_expanded}" ]] && continue
          # use bash string comparison to avoid regex special chars in paths
          while IFS= read -r _diff_line; do
            [[ -z "${_diff_line}" ]] && continue
            if [[ "${_diff_line}" == "${_expanded}" ]] ||
              [[ "${_diff_line}" == "${_expanded}/"* ]]; then
              _hit=1
              break 3
            fi
          done <<<"${diff}"
        done < <(_expand_asset_src "${_entry_src}")
      done <<<"${_assets}"
      [[ ${_hit} -eq 1 ]] && picked["${_image}"]=1
    done
    # if diff had changes but nothing matched any manifest, rebuild everything
    # (e.g. changes only in .github/ or other non-sources paths)
    if [[ ${#picked[@]} -eq 0 ]]; then
      _fill_all_images
    else
      IMAGES_DIRS=()
      readarray -t IMAGES_DIRS < <(
        /usr/bin/env printf '%s\n' "${!picked[@]}" | /usr/bin/env sort
      )
    fi
  fi
fi

for IMAGE_DIR in "${IMAGES_DIRS[@]}"; do
  echo "image [${IMAGE_DIR}] to rebuild"
done
