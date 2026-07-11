#!/usr/bin/env bash
# Usage: apt-sources.sh [with-src]
# Writes /etc/apt/sources.list using $CODENAME and optionally $DISTRO from environment.
# DISTRO defaults to "debian"; set to "ubuntu" for Ubuntu-based images.
set -ueo pipefail
rm -f /etc/apt/sources.list.d/*
{
  proto='http'
  distro="${DISTRO:-debian}"
  if [[ "${distro}" == 'ubuntu' ]]; then
    printf \
      'deb %s://azure.archive.ubuntu.com/ubuntu %s main restricted universe\n' \
      "${proto}" "${CODENAME}"
    printf \
      'deb %s://azure.archive.ubuntu.com/ubuntu %s-updates main restricted universe\n' \
      "${proto}" "${CODENAME}"
    printf \
      'deb %s://azure.archive.ubuntu.com/ubuntu %s-security main restricted universe\n' \
      "${proto}" "${CODENAME}"
    if [[ "${1:-}" == 'with-src' ]]; then
      printf \
        'deb-src %s://azure.archive.ubuntu.com/ubuntu %s main restricted universe\n' \
        "${proto}" "${CODENAME}"
      printf 'deb-src %s://azure.archive.ubuntu.com/ubuntu %s-%s\n' \
        "${proto}" "${CODENAME}" "updates main restricted universe"
      printf 'deb-src %s://azure.archive.ubuntu.com/ubuntu %s-%s\n' \
        "${proto}" "${CODENAME}" "security main restricted universe"
    fi
  else
    printf 'deb %s://deb.debian.org/debian %s main\n' "${proto}" "${CODENAME}"
    printf 'deb %s://deb.debian.org/debian %s-updates main\n' "${proto}" "${CODENAME}"
    printf 'deb %s://security.debian.org/debian-security %s-security main\n' "${proto}" \
      "${CODENAME}"
    if [[ "${1:-}" == 'with-src' ]]; then
      printf 'deb-src %s://deb.debian.org/debian %s main\n' "${proto}" "${CODENAME}"
      printf 'deb-src %s://deb.debian.org/debian %s-updates main\n' "${proto}" \
        "${CODENAME}"
      printf 'deb-src %s://security.debian.org/debian-security %s-security main\n' \
        "${proto}" "${CODENAME}"
    fi
  fi
} >/etc/apt/sources.list
