#!/bin/bash
# cspell:ignore journalctl
# Start systemd as PID 1 and stream the journal to stdout so all systemd
# output is visible via docker logs. journalctl with -b replays all events
# since boot once the journal socket appears, then follows new ones.
set -uo pipefail

(
  socket='/run/systemd/journal/socket'
  until [[ -S "${socket}" ]]; do
    sleep 0.05
  done
  exec journalctl -f -b -o short-monotonic --no-pager 2>/dev/null
) &

exec /lib/systemd/systemd
