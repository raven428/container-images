#!/usr/bin/env bash
set -ueo pipefail
for f in $1; do
  patch -p0 <"files/${f}"
done
rm -rfv files
