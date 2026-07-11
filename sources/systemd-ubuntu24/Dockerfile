# kics-scan disable=b84a0b47-2e99-4c9f-8933-98bcabe2b94d,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f,b03a748a-542d-44f4-bb86-9199ab4fd2d5
FROM ubuntu:24.04 AS builder
ENV CODENAME=noble DISTRO=ubuntu
COPY patches /files/patches
COPY _shared /files/shared
RUN /files/shared/install/systemd-docker/build.sh

FROM ubuntu:24.04
LABEL org.opencontainers.image.source https://github.com/raven428/container-images
ENV container=docker CODENAME=noble DISTRO=ubuntu
COPY --from=builder /tmp/libsystemd-shared_*.deb /tmp/
COPY _shared /files/shared
RUN /files/shared/install/systemd-docker/install.sh
VOLUME ["/tmp", "/run", "/run/lock"]
STOPSIGNAL SIGRTMIN+3
CMD ["/entrypoint.sh"]
