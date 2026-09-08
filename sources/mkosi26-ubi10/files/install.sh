#!/usr/bin/env bash
set -ueo pipefail
# EPEL and CRB (CodeReady Linux Builder) provide extra development packages.
dnf -y install \
  https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
dnf -y install dnf-plugins-core
dnf config-manager --set-enabled \
  "codeready-builder-for-ubi-10-$(uname -m)-rpms"
dnf -y makecache
ROCKY_URL='https://dl.rockylinux.org/pub/rocky/10'
ROCKY_ARCH=$(uname -m)
curl -fLo /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10 \
  https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-10
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10
# Core toolchain for img4vps-build.sh RPM path: dnf, disk tools, QEMU with KVM,
# expect for the automated grub install, pixz for parallel xz.
# Note: package names differ from Debian – iproute (not iproute2), gdisk
# (which provides sgdisk), qemu-kvm-core (not qemu-system-x86).
dnf -y install --allowerasing --setopt=install_weak_deps=False \
  --setopt=tsflags=nodocs \
  bash coreutils util-linux findutils grep sed gawk tar xz zstd curl \
  ca-certificates git openssl \
  gdisk \
  systemd-udev systemd \
  expect \
  rpm python3 python3-dnf-plugin-versionlock \
  cpio kmod file which less vim-minimal iproute iputils \
  python3-pip python3-devel gcc make autoconf automake libtool xz-devel
dnf -y install --setopt=install_weak_deps=False --setopt=tsflags=nodocs \
  --repofrompath="rocky-baseos,${ROCKY_URL}/BaseOS/${ROCKY_ARCH}/os/" \
  --repofrompath="rocky-appstream,${ROCKY_URL}/AppStream/${ROCKY_ARCH}/os/" \
  --repofrompath="rocky-crb,${ROCKY_URL}/CRB/${ROCKY_ARCH}/os/" \
  --setopt=rocky-baseos.gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10 \
  --setopt=rocky-appstream.gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10 \
  --setopt=rocky-crb.gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10 \
  xfsprogs e2fsprogs dosfstools systemd-container \
  qemu-kvm-core qemu-img grub2-pc grub2-tools grub2-tools-minimal \
  libarchive-devel
curl -fL https://github.com/vasi/pixz/releases/download/v1.0.7/pixz-1.0.7.tar.xz | \
  tar -xJ -C /tmp
(
  cd /tmp/pixz-1.0.7
  ./configure --without-manpage
  make -j"$(nproc)"
  make install
)
ln -s /usr/libexec/qemu-kvm /usr/local/bin/qemu-system-x86_64
# mkosi from upstream v26 – the container is named after it, so it must be
# present. img4vps-build.sh does not depend on mkosi, but users may invoke
# mkosi directly for other workflows in the same container.
git clone --depth 1 --branch v26 https://github.com/systemd/mkosi.git /opt/mkosi
ln -s /opt/mkosi/bin/mkosi /usr/local/bin/mkosi
# systemd-repart lives inside the systemd package on EL10 (no separate pkg).
# Verify the binary exists so builds don't fail late.
command -v /usr/bin/systemd-repart >/dev/null || \
  command -v /usr/lib/systemd/systemd-repart >/dev/null || {
    echo "systemd-repart not found in UBI10 systemd package" >&2
    exit 1
  }
dnf clean all
rm -Rf /var/cache/dnf /var/log/dnf.log* /var/log/hawkey.log /files \
  /usr/share/doc /usr/share/man /tmp/pixz-1.0.7
