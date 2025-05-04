# kics-scan disable=b03a748a-542d-44f4-bb86-9199ab4fd2d5,aa93e17f-b6db-4162-9334-c70334e7ac28,fd54f200-402c-4333-a5a4-36ef6709af2f
FROM openwrt/imagebuilder:rockchip-armv8-v24.10.1
LABEL org.opencontainers.image.source https://github.com/raven428/container-images
# workaround to remove /builder volume from openwrt/buildbot/buildworker
WORKDIR /builder
COPY --chown=buildbot:buildbot files files
RUN files/install.sh "rock-armv8.diff"
# hadolint ignore=DL3002
USER root:root
