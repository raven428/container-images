# kics-scan disable=b84a0b47-2e99-4c9f-8933-98bcabe2b94d,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f,b03a748a-542d-44f4-bb86-9199ab4fd2d5
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

# Patch libsystemd-shared so that cg_create and cg_attach silently succeed
# when /sys/fs/cgroup is read-only (standard unprivileged Docker with cgroup v2).
# Binary offsets are specific to systemd 252.39-1~deb12u2 amd64.
#
# cg_create  @ 0x9d7f0: after mkdir fails, jump to success path
#   patch: 0x9d84a  78 54  ->  eb 20
#          (jmp +0x20 to mov $1,%ebx / return-1-success path)
#
# cg_attach  @ 0x9d950: after write_string_file_ts fails, zero ebx and jump
#   patch: 0x9d9fc  85 c0 78 26  ->  31 db eb 24
#          (xor ebx,ebx; jmp +0x24 to cleanup / return-0 path)
COPY patch-libsystemd.py /tmp/patch-libsystemd.py
RUN python3 /tmp/patch-libsystemd.py && rm /tmp/patch-libsystemd.py

RUN systemd-machine-id-setup

# Remove units that require kernel access unavailable in unprivileged Docker
RUN systemctl mask \
  systemd-udevd.service \
  systemd-udevd-control.socket \
  systemd-udevd-kernel.socket \
  systemd-modules-load.service \
  kmod-static-nodes.service \
  systemd-sysctl.service \
  systemd-tmpfiles-setup-dev.service \
  systemd-tmpfiles-setup-dev-early.service \
  systemd-remount-fs.service \
  systemd-random-seed.service \
  systemd-machine-id-commit.service \
  systemd-firstboot.service \
  systemd-pstore.service \
  systemd-rfkill.service \
  systemd-rfkill.socket \
  systemd-journald-audit.socket \
  proc-sys-fs-binfmt_misc.automount \
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
