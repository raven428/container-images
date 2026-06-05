#!/usr/bin/env bash
set -ueo pipefail
: "${TARGET_REGISTRY:=ghcr.io/raven428/container-images}"
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
    # transitive hits via SHARED_ASSETS: source each vars.sh in a subshell
    # with side-effect commands neutralized via _build_vars_shunts
    for _dir in sources/*/; do
      [[ -f "${_dir}vars.sh" ]] || continue
      _image="${_dir%/}"
      [[ -n "${picked[${_image}]:-}" ]] && continue
      _assets="$(
        eval "$(_build_vars_shunts "${_dir}vars.sh")"
        # shellcheck disable=2034
        TAG="${_image#sources/}"
        IMAGE_DIR="${_image}"
        SHARED_ASSETS=()
        # shellcheck disable=1090
        source "${_dir}vars.sh" 2>/dev/null || true
        /usr/bin/env printf '%s\n' "${SHARED_ASSETS[@]:-}"
      )"
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
