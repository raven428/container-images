# kics-scan disable=b84a0b47-2e99-4c9f-8933-98bcabe2b94d,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f,b03a748a-542d-44f4-bb86-9199ab4fd2d5
FROM debian:bookworm-slim AS builder
ARG DEBIAN_FRONTEND=noninteractive

RUN rm -f /etc/apt/sources.list.d/* && \
  printf 'deb http://deb.debian.org/debian bookworm main\n\
deb http://deb.debian.org/debian bookworm-updates main\n\
deb http://security.debian.org/debian-security bookworm-security main\n\
deb-src http://deb.debian.org/debian bookworm main\n\
deb-src http://deb.debian.org/debian bookworm-updates main\n\
deb-src http://security.debian.org/debian-security bookworm-security main\n' \
    >/etc/apt/sources.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential dpkg-dev devscripts fakeroot debhelper && \
  apt-get build-dep -y systemd && \
  apt-get source systemd
COPY patches/ /patches/
RUN cd systemd-* && \
  for p in /patches/*.patch; do patch -p1 < "$p"; done && \
  DEB_BUILD_OPTIONS='nocheck nodoc' \
  DEB_BUILD_PROFILES='nocheck noinsttest nodoc' \
  dpkg-buildpackage -b -uc -us -j"$(nproc)"

FROM debian:bookworm-slim
LABEL org.opencontainers.image.source https://github.com/raven428/container-images
ARG DEBIAN_FRONTEND=noninteractive
ENV container=docker

RUN rm -f /etc/apt/sources.list.d/* && \
  printf 'deb http://deb.debian.org/debian bookworm main\n\
deb http://deb.debian.org/debian bookworm-updates main\n\
deb http://security.debian.org/debian-security bookworm-security main\n' \
    >/etc/apt/sources.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    systemd python3 sudo bash less ca-certificates iproute2 \
    python3-apt aptitude python3-psutil xz-utils openssh-server && \
  systemctl enable ssh && \
  apt-get clean && \
  rm -rf /usr/share/doc /usr/share/man /var/lib/apt/lists/*

COPY --from=builder /libsystemd-shared_*.deb /tmp/
RUN dpkg -i /tmp/libsystemd-shared_*.deb && rm /tmp/*.deb

RUN systemd-machine-id-setup

# Remove units that require kernel access unavailable in unprivileged Docker
RUN systemctl mask \
  systemd-udevd.service \
  systemd-udevd-control.socket \
  systemd-udevd-kernel.socket \
  systemd-modules-load.service \
  kmod-static-nodes.service \
  kmod.service \
  systemd-sysctl.service \
  systemd-hwdb-update.service \
  systemd-tmpfiles-setup-dev.service \
  systemd-tmpfiles-setup-dev-early.service \
  systemd-remount-fs.service \
  systemd-random-seed.service \
  systemd-machine-id-commit.service \
  systemd-firstboot.service \
  systemd-pstore.service \
  systemd-binfmt.service \
  systemd-rfkill.service \
  systemd-rfkill.socket \
  systemd-journald-audit.socket \
  systemd-tpm2-setup-early.service \
  systemd-tpm2-setup.service \
  systemd-battery-check.service \
  proc-sys-fs-binfmt_misc.automount \
  proc-sys-fs-binfmt_misc.mount \
  dev-hugepages.mount \
  dev-mqueue.mount \
  sys-fs-fuse-connections.mount \
  sys-kernel-config.mount \
  sys-kernel-debug.mount \
  sys-kernel-tracing.mount \
  console-getty.service \
  getty@.service \
  getty-static.service \
  serial-getty@.service \
  autovt@.service

RUN mkdir -p /etc/systemd/journald.conf.d && \
  printf '[Journal]\nStorage=volatile\n' \
    >/etc/systemd/journald.conf.d/10-docker.conf

RUN mkdir -p /etc/systemd/system.conf.d && \
  printf '[Manager]\nDefaultStandardOutput=journal\nDefaultStandardError=journal\n\
ShowStatus=no\nDefaultTimeoutStartSec=15s\n\
DefaultTimeoutStopSec=10s\n' \
    >/etc/systemd/system.conf.d/10-docker.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

VOLUME ["/tmp", "/run", "/run/lock"]
STOPSIGNAL SIGRTMIN+3
CMD ["/entrypoint.sh"]
