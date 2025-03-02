#!/usr/bin/env bash
set -ueo pipefail
export PATH="$PYENV_ROOT/bin:$PATH"
export DEBIAN_FRONTEND='noninteractive'
apt-get install -y git curl libreadline-dev libsqlite3-dev libbz2-dev gcc g++ make \
  zlib1g-dev libssl-dev libffi-dev liblzma-dev
curl -sLm 11 \
  https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer |
  bash
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv install 3.11.11
pyenv virtualenv 3.11.11 ansible
