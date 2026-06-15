#!/bin/bash
set -e
if [[ $# -gt 0 ]]; then
  exec "$@"
fi
export SCREEN_WIDTH="${SCREEN_WIDTH:-1920}"
export SCREEN_HEIGHT="${SCREEN_HEIGHT:-1080}"
export SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
