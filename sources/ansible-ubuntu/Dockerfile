FROM ubuntu:24.04
COPY files /files
COPY _shared /files/shared
ENV PYENV_ROOT='/pye'
ENV PATH="/ansbl:$PATH"
RUN /files/install.sh
