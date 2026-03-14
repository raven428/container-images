#!/usr/bin/env bash

cleanup_python_packages() {
  local python_root="$1"
  echo "Cleaning up Python packages..."
  find "${python_root}" -depth \
    \( \
    \( -type d -a \( \
    -name test -o -name tests -o -name __pycache__ \
    \) -a -not -path '*/ansible/plugins/test' \) \
    -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
    -o \( -type f -a -name 'wininst-*.exe' \) \
    \) -exec rm -rf '{}' +
}

apply_flush_line_patch() {
  local python_root="$1"
  local patch_file="$2"
  local ansible_version="$3"

  # ansible-06 doesn't use flush-line.diff
  if [[ "${ansible_version}" == "06" ]]; then
    echo "Skipping flush-line.diff for ansible-06 (not needed)"
    return
  fi

  if [[ ! -f "${patch_file}" ]]; then
    echo "Warning: flush-line.diff not found at ${patch_file}, skipping"
    return
  fi

  echo "Applying flush-line.diff patch..."
  # shellcheck disable=2164
  cd "${python_root}"
  patch -p0 <"${patch_file}"
}

copy_system_libs() {
  local appdir="$1"
  shift
  local packages=("$@")
  echo "Copying system libraries from packages: ${packages[*]}"
  local lib_dir="${appdir}/lib"
  mkdir -p "${lib_dir}"
  for pkg in "${packages[@]}"; do
    # dpkg may not know about meta-packages or virtual ones — skip silently
    dpkg -L "${pkg}" 2>/dev/null || continue
  done | grep -E '\.so(\.[0-9]+)*$' | while read -r src; do
    [[ -e "${src}" || -L "${src}" ]] || continue
    dst="${lib_dir}/$(basename "${src}")"
    if [[ -L "${src}" ]]; then
      # Preserve symlinks as-is (relative target kept)
      ln -sf "$(readlink "${src}")" "${dst}"
    else
      cp -a "${src}" "${dst}"
    fi
  done
}

find_package() {
  apt-cache search --names-only "$1" 2>/dev/null |
    awk '{printf "%s ", $1}'
}

python_runtime_packages() {
  find_package '^libreadline[_\.0-9\-]+$'
  find_package '^libsqlite[_\.0-9\-]+$'
  find_package '^libbz[_\.0-9\-]+$'
  find_package '^zlib[\.0-9\-]+[a-z]$'
  find_package '^libssl[0-9]'
  find_package '^libffi[0-9]+$'
  find_package '^liblzma[0-9]+$'
}

apply_async_check_patch() {
  local python_root="$1"
  local patch_file="$2"
  local ansible_version="$3"

  # async-check.diff only for ansible-06, 07, 08, 09
  case "${ansible_version}" in
  06 | 07 | 08 | 09)
    if [[ ! -f "${patch_file}" ]]; then
      echo "Warning: async-check.diff not found at ${patch_file}, skipping"
      return
    fi

    echo "Applying async-check.diff patch for ansible-${ansible_version}..."
    # shellcheck disable=2164
    cd "${python_root}"

    if [[ "${ansible_version}" == "06" ]]; then
      # ansible-06: modified version (only first part, without __init__.py)
      awk \
        '/^--- .+site-packages\/ansible\/plugins\/action\/__init__/ { exit } { print }' \
        "${patch_file}" | patch -p0

      # Additional sed fix for ansible-06
      sed -ri '/^\s+elif self._task.async_val and self\..+$/d;
/^.+check mode and async cannot be used on same task.+$/d' \
        lib/python*/site-packages/ansible/plugins/action/__init__.py
    else
      # ansible-07, 08, 09: full patch
      patch -p0 <"${patch_file}"
    fi
    ;;
  *)
    echo "Skipping async-check.diff for ansible-${ansible_version} (not needed)"
    ;;
  esac
}
