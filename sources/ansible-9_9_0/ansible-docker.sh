#!/usr/bin/env bash
set -ueo pipefail
: "${ANSIBLE_PATH:="."}"
: "${ANSIBLE_PATH2CONT:="/ansible"}"
: "${ANSIBLE_CONT_NAME:="ansible-${USER}"}"
: "${ANSIBLE_USERDIR:="${HOME}/.ansible"}"
: "${ANSIBLE_IMAGE_NAME:="ghcr.io/raven428/container-images/ansible-9_9_0:latest"}"
: "${ANSIBLE_IMAGE_SHORT:="ansible:latest"}"
/usr/bin/env mkdir -vp "${ANSIBLE_USERDIR}"/{ssh,tmp}
/usr/bin/env cat <<EOF | /usr/bin/env sponge "${ANSIBLE_USERDIR}/ssh/config"
# ssh config for Ansible
SendEnv=LC_*
SendEnv=LANG
SendEnv=ANSIBLE_*
SendEnv=RSYNC_RSH
ForwardAgent=yes
ControlMaster=auto
ControlPersist=111m
HostKeyAlgorithms=ssh-ed25519,ssh-dss
StrictHostKeyChecking=accept-new
PreferredAuthentications=publickey
ControlPath=${ANSIBLE_USERDIR}/ssh/host-%r@%h:%p
UserKnownHostsFile=${ANSIBLE_USERDIR}/ssh/known_hosts

Include ${ANSIBLE_USERDIR}/ssh/conf.d/*
EOF
export ANSIBLE_SSH_ARGS="-F ${ANSIBLE_USERDIR}/ssh/config"
export RSYNC_RSH="/usr/bin/env ssh ${ANSIBLE_SSH_ARGS}"
# shellcheck disable=2016
mapfile -t env2cont < <(
  /usr/bin/env printenv |
    /usr/bin/env egrep '^ANSIBLE_|RSYNC_RSH' |
    /usr/bin/env awk -F '=' '{ printf "-e " $1 " " }'
)
ANSIBLE_PATH="$(readlink -f "${ANSIBLE_PATH}")"
pushd "${ANSIBLE_PATH}" >/dev/null
# restore files timestamps from git history
# by https://stackoverflow.com/a/22638823/4149412 -
/usr/bin/env git config log.showSignature false
# shellcheck disable=2016
/usr/bin/env git log --pretty=%at --name-status --reverse |
  /usr/bin/env perl -ane '
  ($x, $f) = @F;
  next if(not $x);
  $t = $x, next if(not defined($f) or $s{$f});
  $s{$f} = utime($t, $t, $f), next if($x =~ /[AM]/);
'
popd >/dev/null
if [[ "$(
  /usr/bin/env docker inspect "${ANSIBLE_CONT_NAME}" -f "
    {{- range .Mounts -}}
      {{- if eq .Destination \"${ANSIBLE_PATH2CONT}\" -}}
        {{- .Source -}}{{- break -}}
      {{- end -}}
    {{- end -}}
  " 2>/dev/null || true
)" != "${ANSIBLE_PATH}" ]]; then
  echo "path changed to [${ANSIBLE_PATH}], destroying container…"
  /usr/bin/env docker rm -f "${ANSIBLE_CONT_NAME}" 2>/dev/null || true
fi
if [[ "$(
  /usr/bin/env docker container inspect -f '{{.State.Status}}' \
  "${ANSIBLE_CONT_NAME}" 2>/dev/null || true
)" != "running" ]]; then
  /usr/bin/env docker image pull "${ANSIBLE_IMAGE_NAME}"
  /usr/bin/env docker image tag "${ANSIBLE_IMAGE_NAME}" "${ANSIBLE_IMAGE_SHORT}"
  /usr/bin/env docker run  \
    -d --rm --network=host \
    --name="${ANSIBLE_CONT_NAME}" \
    --hostname="${ANSIBLE_CONT_NAME}" \
    -v /etc/group:/etc/group:ro \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/shadow:/etc/shadow:ro \
    -v "${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}" \
    -v "${ANSIBLE_USERDIR}:${ANSIBLE_USERDIR}" \
    -v "${ANSIBLE_PATH}:${ANSIBLE_PATH2CONT}:ro" \
    "${ANSIBLE_IMAGE_SHORT}" \
    sleep 5555
fi
# shellcheck disable=2068
/usr/bin/env docker exec -u "${UID}" \
  -i -w "${ANSIBLE_PATH2CONT}" \
  -e "ANSIBLE_FORCE_COLOR=True" \
  -e "SSH_AUTH_SOCK" \
  ${env2cont[@]} \
  "${ANSIBLE_CONT_NAME}" \
  "${@}"
