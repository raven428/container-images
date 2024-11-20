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
    /usr/bin/env apt-get update && /usr/bin/env apt-get install git
  else
    /usr/bin/env apk update && /usr/bin/env apk add git
  fi
case ${CI_PIPELINE_SOURCE:-} in
push)
  diff_source="${CI_COMMIT_BEFORE_SHA}"
  diff_target="${CI_COMMIT_SHA}"
  ;;
merge_request_event)
  diff_source="remotes/origin/${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME}"
  diff_target="remotes/origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
  ;;
*)
  diff_source='remotes/origin/master'
  diff_target="."
  ;;
esac
if [[ "${MANUAL_IMAGES_DIRS}" != "" ]]; then
  diff=''
  for dir in ${MANUAL_IMAGES_DIRS}; do
    diff="${diff}sources/${dir}\n"
  done
else
  diff=$(
    /usr/bin/env git diff --name-only \
      "${diff_source}" "${diff_target}" |
      /usr/bin/env egrep -v '^(README\.md)|(\.gitignore)$' || true
  )
fi
if [[ "${diff}" == "" ]]; then
  diff=$(find sources/* -type f)
fi
/usr/bin/env printf "\n———⟨ diff: ⟩———\n${diff}\n\n———⟨ images: ⟩———\n"
if /usr/bin/env printf "${diff}" | /usr/bin/env fgrep -v 'sources/' >/dev/null; then
  # rebuild all in case of framework changes
  echo 'all images to rebuild:'
  source_dirs='sources/*'
else
  # rebuild only changed images in other case
  # shellcheck source=/dev/null
  /usr/bin/env printf "${diff}" |
    /usr/bin/env fgrep '_shared' && source '_shared/vars.sh'
  # shellcheck disable=2016
  source_dirs="$(
    /usr/bin/env printf "${diff}" |
      /usr/bin/env fgrep 'sources/' |
      /usr/bin/env awk -F '/' '{ print $1 "/" $2 }' |
      /usr/bin/env sort |
      /usr/bin/env uniq
  )"
fi
IMAGES_DIRS=()
for IMAGE_DIR in ${source_dirs}; do
  [[ ! -d "${IMAGE_DIR}" ]] && continue
  IMAGES_DIRS+=("${IMAGE_DIR}")
  echo "image [${IMAGE_DIR}] to rebuild"
done
