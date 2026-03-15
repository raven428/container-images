#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  git ca-certificates python3 debootstrap systemd-container xfsprogs e2fsprogs \
  dosfstools btrfs-progs squashfs-tools debian-archive-keyring ubuntu-keyring fdisk \
  util-linux udev kmod zstd xz-utils cpio curl grub-pc-bin grub-common python3-pefile \
  qemu-utils
git clone --depth 1 --branch v26 https://github.com/systemd/mkosi.git /opt/mkosi
ln -s /opt/mkosi/bin/mkosi /usr/local/bin/mkosi
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /files
