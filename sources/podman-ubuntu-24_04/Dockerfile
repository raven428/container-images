# kics-scan disable=b03a748a-542d-44f4-bb86-9199ab4fd2d5,fd54f200-402c-4333-a5a4-36ef6709af2f
FROM ubuntu:24.04
RUN rm -f /etc/apt/sources.list.d/* && \
  printf 'deb http://azure.archive.ubuntu.com/ubuntu noble main restricted universe \
  multiverse\ndeb http://azure.archive.ubuntu.com/ubuntu noble-updates main restricted \
  universe multiverse\ndeb http://azure.archive.ubuntu.com/ubuntu noble-security main \
  restricted universe multiverse\n' >/etc/apt/sources.list
COPY podman.sh /podman.sh
RUN /podman.sh
