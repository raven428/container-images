#!/bin/bash
# Launch obsidian inside the running dbus-run-session started by the xfce service.
# We resolve DBUS_SESSION_BUS_ADDRESS dynamically by reading it from the
# environment of the dbus-run-session process that owns the xfce session.
set -e

# Find the dbus-run-session process owned by the obsidian user and grab its env.
_dbus_pid=$(pgrep -u obsidian -x dbus-run-session 2>/dev/null | head -1)
if [[ -n "${_dbus_pid}" ]]; then
  _addr=$(tr '\0' '\n' <"/proc/${_dbus_pid}/environ" 2>/dev/null |
    grep '^DBUS_SESSION_BUS_ADDRESS=' | head -1)
  [[ -n "${_addr}" ]] && export _addr
fi

exec /usr/bin/obsidian --no-sandbox --disable-gpu-sandbox /vault
