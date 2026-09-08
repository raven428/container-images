#!/usr/bin/env bash
# cspell:ignore makecache allowerasing tsflags nodocs findutils versionlock libexec
# cspell:ignore hawkey
set -ueo pipefail
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
dnf -y install dnf-plugins-core
dnf config-manager --set-enabled crb
dnf -y makecache
dnf -y install --allowerasing --setopt=install_weak_deps=False --setopt=tsflags=nodocs \
  bash coreutils util-linux findutils grep sed gawk tar xz zstd curl ca-certificates \
  git openssl xfsprogs e2fsprogs dosfstools systemd-udev systemd-container systemd \
  qemu-kvm-core qemu-img expect grub2-pc grub2-tools grub2-tools-minimal rpm python3 \
  python3-dnf-plugin-versionlock cpio kmod file which less vim-minimal iproute iputils \
  python3-pip python3-devel gcc make gdisk
ln -s /usr/libexec/qemu-kvm /usr/local/bin/qemu-system-x86_64
git clone --depth 1 --branch v26 https://github.com/systemd/mkosi.git /opt/mkosi
ln -s /opt/mkosi/bin/mkosi /usr/local/bin/mkosi
command -v systemd-repart >/dev/null
dnf clean all
rm -Rf /var/cache/dnf /var/log/dnf.log* /var/log/hawkey.log /files /usr/share/doc \
  /usr/share/man
