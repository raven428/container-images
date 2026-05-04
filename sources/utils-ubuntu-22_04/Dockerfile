# kics-scan disable=b03a748a-542d-44f4-bb86-9199ab4fd2d5,f45ea400-6bbe-4501-9fc7-1c3d75c32067,965a08d7-ef86-4f14-8792-4a3b2098937e,fd54f200-402c-4333-a5a4-36ef6709af2f
FROM ubuntu:22.04
RUN rm -f /etc/apt/sources.list.d/* && \
  printf 'deb http://azure.archive.ubuntu.com/ubuntu jammy main restricted universe \
  multiverse\ndeb http://azure.archive.ubuntu.com/ubuntu jammy-updates main restricted \
  universe multiverse\ndeb http://azure.archive.ubuntu.com/ubuntu jammy-security main \
  restricted universe multiverse\n' >/etc/apt/sources.list
ENV LANG='en_US.UTF-8'
ENV LC_TIME='en_GB.UTF-8'
ENV LANGUAGE='en_US.UTF-8'
COPY files /files
COPY _shared /files/shared
RUN /files/install.sh
