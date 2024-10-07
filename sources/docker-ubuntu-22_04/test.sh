#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2016
test_cont_name=$(
  /usr/bin/env mktemp -u |
    # workaround for "mktemp: Invalid argument" with busybox from alpine
    /usr/bin/env awk -F '.' '{ print "test-systemd-ubuntu-" $2 }'
)
/usr/bin/env docker run \
  --network=host \
  -d --privileged \
  --cgroupns=host \
  --name "${test_cont_name}" \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  "${TARGET_REGISTRY}/${TAG}:${IMAGE_VER}"
count=7
while ! /usr/bin/env docker exec "${test_cont_name}" systemctl status; do
  echo "waiting container ready, left [$count] tries"
  count=$((count - 1))
  if [[ $count -le 0 ]]; then
    break
  fi
  sleep 1
done
if [[ $count -gt 0 ]]; then
  echo 'test success'
  TEST_RESULT=0
else
  echo 'test failed'
  # shellcheck disable=2034
  TEST_RESULT=1
fi
/usr/bin/env docker rm -f "${test_cont_name}" |
  /usr/bin/awk '{print "container [" $0 "] destroyed"}'
