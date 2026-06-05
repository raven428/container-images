#!/usr/bin/env bash
# Usage: apt-sources.sh [with-src]
# Writes /etc/apt/sources.list using $CODENAME from environment.
set -ueo pipefail
rm -f /etc/apt/sources.list.d/*
{
  proto='http'
  printf 'deb %s://deb.debian.org/debian %s main\n' "${proto}" "${CODENAME}"
  printf 'deb %s://deb.debian.org/debian %s-updates main\n' "${proto}" "${CODENAME}"
  printf 'deb %s://security.debian.org/debian-security %s-security main\n' "${proto}" \
    "${CODENAME}"
  if [[ "${1:-}" == 'with-src' ]]; then
    printf 'deb-src %s://deb.debian.org/debian %s main\n' "${proto}" "${CODENAME}"
    printf 'deb-src %s://deb.debian.org/debian %s-updates main\n' "${proto}" "${CODENAME}"
    printf 'deb-src %s://security.debian.org/debian-security %s-security main\n' \
      "${proto}" "${CODENAME}"
  fi
} >/etc/apt/sources.list
