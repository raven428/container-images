#!/usr/bin/env bash
set -ueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y podman golang-github-containers-common golang-github-containers-image \
  aardvark-dns netavark containernetworking-plugins
mkdir -vp /etc/apt/sources.list.d
curl -fsSLm 11 "https://downloadcontent.opensuse.org/repositories/home:/alvistack\
/xUbuntu_24.04/Release.key" \
  -o /etc/apt/keyrings/podman.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/podman.asc] \
https://downloadcontent.opensuse.org/repositories/home:/alvistack/xUbuntu_24.04 /" \
  >/etc/apt/sources.list.d/podman.list
apt-get update -y
apt-get install -y podman podman-netavark
