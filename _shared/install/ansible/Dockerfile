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
