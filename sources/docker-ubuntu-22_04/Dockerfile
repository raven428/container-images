FROM ubuntu:22.04
COPY _shared /files
RUN /files/install/docker/install.sh

VOLUME ["/sys/fs/cgroup", "/tmp", "/run"]
CMD ["/lib/systemd/systemd"]
