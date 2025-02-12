FROM ghcr.io/raven428/container-images/ansible-builder:latest AS build
COPY files /files
RUN /files/build.sh

FROM ghcr.io/raven428/container-images/ansible-ubuntu:latest
COPY --from=build ${PYENV_ROOT}/versions/ ${PYENV_ROOT}/versions/
RUN rm -Rf /files
