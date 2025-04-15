#!/usr/bin/env bash
set -ueo pipefail
ls -la target/linux/mediatek/image/filogic.mk
patch -p0 <files/filogic.diff
ls -la target/linux/mediatek/image/filogic.mk
rm -rfv files
