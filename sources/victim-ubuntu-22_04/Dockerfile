FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -y apt-utils systemd python3 sudo bash \
  ca-certificates iproute2 python3-apt aptitude python3-psutil \
  secure-delete openssh-server && \
  systemctl enable systemd-networkd ssh &&\
  apt-get clean && \
  rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/*

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
  && rm -f /lib/systemd/system/getty.target

VOLUME ["/sys/fs/cgroup", "/tmp", "/run"]
CMD ["/lib/systemd/systemd"]
