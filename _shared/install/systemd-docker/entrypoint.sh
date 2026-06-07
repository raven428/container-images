#!/bin/bash
# cspell:ignore journalctl
# Start systemd as PID 1 and stream the journal to stdout so all systemd
# output is visible via docker logs. journalctl follows new entries without
# -b so it is not tied to a boot ID and survives journal rotation.
set -uo pipefail

(
  socket='/run/systemd/journal/socket'
  until [[ -S "${socket}" ]]; do
    sleep 0.05
  done
  # Wait until journald has written at least one entry so the cursor is
  # positioned correctly and -f does not miss early boot messages.
  until journalctl -n 1 --no-pager -q 2>/dev/null | grep -q .; do
    sleep 0.05
  done
  exec journalctl -f -o short-monotonic --no-pager 2>/dev/null
) &

exec /lib/systemd/systemd
