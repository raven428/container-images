FROM ghcr.io/raven428/container-images/ansible-11_1_0:latest
COPY _shared /files
RUN /files/install/docker/install.sh

VOLUME ["/sys/fs/cgroup", "/tmp", "/run"]
CMD ["/lib/systemd/systemd"]
