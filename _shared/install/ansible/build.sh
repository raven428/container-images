#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=SC1091
source "${PYENV_ROOT}/versions/ansible/bin/activate"
pip install --upgrade pip
pip install -r files/requirements.txt
# enable flush elsewhere molecule -v create doesn't progress "Wait for instance(s)
# creation to complete" after "Create molecule instance(s)" task
{
  cd "${PYENV_ROOT}/versions/ansible"
  patch -p0 </files/flush-line.diff
}
# https://github.com/vicamo/docker-pyenv/blob/main/jammy/Dockerfile
# TASK external/nftables : Combine Rules when nft_merged_groups is set
# failure with removed "ansible/plugins/test" for some reason
find "${PYENV_ROOT}/versions" -depth \
  \( \
  \( -type d -a \( \
  -name test -o -name tests -o -name __pycache__ \
  \) -a -not -path '*/ansible/plugins/test' \) \
  -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
  -o \( -type f -a -name 'wininst-*.exe' \) \
  \) -exec rm -rf '{}' +
