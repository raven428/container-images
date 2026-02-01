#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=SC1091
source "${PYENV_ROOT}/versions/ansible/bin/activate"
pip install --upgrade pip
pip install -r files/requirements.txt

# Source common functions
# shellcheck disable=SC1091
source /files/common.sh

# Extract ansible version from TAG
ANSIBLE_VERSION="${TAG#ansible-}"

# Cleanup Python packages
cleanup_python_packages "${PYENV_ROOT}/versions"

# Apply patches
apply_flush_line_patch "${PYENV_ROOT}/versions/ansible" "/files/flush-line.diff" "${ANSIBLE_VERSION}"
apply_async_check_patch "${PYENV_ROOT}/versions/ansible" "/files/async-check.diff" "${ANSIBLE_VERSION}"
