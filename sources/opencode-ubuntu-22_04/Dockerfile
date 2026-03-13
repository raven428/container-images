# kics-scan disable=b03a748a-542d-44f4-bb86-9199ab4fd2d5,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f,0008c003-79aa-42d8-95b8-1c2fe37dbfe6
FROM ubuntu:24.04
ENV _CONTAINERS_USERNS_CONFIGURED=''
ENV BUILDAH_ISOLATION='chroot'
ENV LANG='en_US.UTF-8'
ENV LC_TIME='en_GB.UTF-8'
ENV LANGUAGE='en_US.UTF-8'
COPY files /files
COPY _shared /files/shared
RUN /files/install.sh
RUN curl -sLo /usr/local/bin/opencode "https://github.com/raven428/opencode-ctrl/releases/download/v1.2.16p4/opencode-v1_2_16-linux-x64" && chmod -v 755 /usr/local/bin/opencode
USER coder
VOLUME ["/srv/data/podman/main", "/home/coder"]
