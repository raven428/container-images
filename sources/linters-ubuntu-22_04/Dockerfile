FROM ubuntu:22.04
COPY --chmod=755 files/install.sh /files/install.sh
RUN /files/install.sh
COPY --chmod=755 files/check-syntax.sh /
COPY --chmod=755 _shared/prepare2check.sh /
