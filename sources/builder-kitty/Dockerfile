# kics-scan disable=b03a748a-542d-44f4-bb86-9199ab4fd2d5,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f
FROM ubuntu:24.04
LABEL org.opencontainers.image.source https://github.com/raven428/container-images
ENV DEBIAN_FRONTEND='noninteractive'
COPY files /files
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && /files/install.sh
ENV PATH="/usr/local/go/bin:/usr/local/bin:${PATH}"
WORKDIR /sources
VOLUME ["/sys/fs/cgroup", "/tmp", "/run"]
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
