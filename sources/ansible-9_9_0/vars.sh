#!/usr/bin/env bash
set -ueo pipefail
export IMAGE_VER='000'
/usr/bin/env rm -rfv sources/ansible-9_9_0/_shared
/usr/bin/env cp -rfv _shared sources/ansible-9_9_0
