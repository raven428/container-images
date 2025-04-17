# kics-scan disable=b84a0b47-2e99-4c9f-8933-98bcabe2b94d,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f,b03a748a-542d-44f4-bb86-9199ab4fd2d5
FROM ubuntu:22.04
LABEL org.opencontainers.image.source https://github.com/raven428/container-images
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -y --no-install-recommends apt-utils systemd python3 sudo bash \
  ca-certificates iproute2 python3-apt aptitude python3-psutil xz-utils \
  secure-delete openssh-server && \
  systemctl enable ssh && \
  apt-get clean && \
  rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/*

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
  && rm -f /lib/systemd/system/getty.target

VOLUME ["/sys/fs/cgroup", "/tmp", "/run"]
CMD ["/lib/systemd/systemd"]
