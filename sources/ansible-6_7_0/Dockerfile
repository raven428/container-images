FROM ubuntu:24.04
COPY files /files
COPY _shared /files/shared
ENV PATH="/venv/bin:$PATH"
RUN /files/install.sh
