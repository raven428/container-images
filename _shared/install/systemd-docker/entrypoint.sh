#!/bin/bash
# cspell:ignore journalctl
# Installed as /sbin/init so podman enables its systemd mode by the command path.
# Starts systemd as PID 1 and streams the journal to stdout so all systemd output is
# visible via podman logs. journalctl follows new entries without -b so it is not tied
# to a boot ID and survives journal rotation.
set -uo pipefail

(
  # With an allocated tty systemd takes over the terminal and SIGHUPs this reader.
  # An ignored disposition survives the exec below, unlike a handler.
  trap '' HUP
  socket='/run/systemd/journal/socket'
  until [[ -S "${socket}" ]]; do
    sleep 0.05
  done
  # Wait until journald has written at least one entry so the cursor is
  # positioned correctly and -f does not miss early boot messages.
  until journalctl -n 1 --no-pager -q 2>/dev/null | grep -q .; do
    sleep 0.05
  done
  exec journalctl -f -n all -o short-monotonic --no-pager 2>/dev/null
) &

exec /lib/systemd/systemd
