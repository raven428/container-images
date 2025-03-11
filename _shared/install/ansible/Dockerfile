# kics-scan disable=b03a748a-542d-44f4-bb86-9199ab4fd2d5,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f
FROM ghcr.io/raven428/container-images/ansible-builder:latest AS build
COPY files/requirements.txt /files/requirements.txt
COPY files/flush-line.diff /files/flush-line.diff
COPY files/build.sh /files/build.sh
RUN /files/build.sh

FROM ghcr.io/raven428/container-images/ansible-ubuntu:latest
COPY --from=build ${PYENV_ROOT}/versions/ ${PYENV_ROOT}/versions/
COPY _shared /files/shared
COPY files /files
RUN /files/configure.sh
