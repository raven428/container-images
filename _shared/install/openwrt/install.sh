#!/usr/bin/env bash
set -ueo pipefail
patch -p0 <files/filogic.diff
rm -rfv files
