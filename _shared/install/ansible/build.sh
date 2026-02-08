#!/usr/bin/env bash
set -ueo pipefail
env_dir="${PYENV_ROOT}/versions/${PYTHON_VERSION}"
cd "${env_dir}"
bin/python -m pip install --upgrade pip
bin/python -m pip install -r /files/requirements.txt

# Source common functions
# shellcheck disable=SC1091
source /files/common.sh

# Extract ansible version from TAG
ANSIBLE_VERSION="${TAG#ansible-}"

# Cleanup Python packages
cleanup_python_packages "${env_dir}"

# Apply patches
apply_flush_line_patch "${env_dir}" "/files/flush-line.diff" "${ANSIBLE_VERSION}"
apply_async_check_patch "${env_dir}" "/files/async-check.diff" "${ANSIBLE_VERSION}"
