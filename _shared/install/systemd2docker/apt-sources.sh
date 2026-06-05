#!/usr/bin/env bash
# Usage: apt-sources.sh [with-src]
# Writes /etc/apt/sources.list using $CODENAME from environment.
set -ueo pipefail
rm -f /etc/apt/sources.list.d/*
{
  printf 'deb http://deb.debian.org/debian %s main\n' "${CODENAME}"
  printf 'deb http://deb.debian.org/debian %s-updates main\n' "${CODENAME}"
  printf \
    'deb http://security.debian.org/debian-security %s-security main\n' \
    "${CODENAME}"
  if [[ "${1:-}" == 'with-src' ]]; then
    printf 'deb-src http://deb.debian.org/debian %s main\n' "${CODENAME}"
    printf 'deb-src http://deb.debian.org/debian %s-updates main\n' \
      "${CODENAME}"
    printf \
      'deb-src http://security.debian.org/debian-security %s-security main\n' \
      "${CODENAME}"
  fi
} >/etc/apt/sources.list
