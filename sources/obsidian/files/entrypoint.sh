#!/bin/bash
# cspell:ignore openrc RDWR mkfifo confd
set -e
if [[ $# -gt 0 ]]; then
  exec "$@"
fi

# distribute env_<svc>_<VAR>=value into /etc/conf.d/<svc>
# e.g. env_xvfb_SCREEN_WIDTH=1280 -> /etc/conf.d/xvfb: SCREEN_WIDTH="1280"
while IFS='=' read -r _key _val; do
  [[ "${_key}" =~ ^env_([^_]+)_(.+)$ ]] || continue
  _svc="${BASH_REMATCH[1]}"
  _var="${BASH_REMATCH[2]}"
  printf '%s="%s"\n' "${_var}" "${_val}" >>"/etc/conf.d/${_svc}"
done < <(env)

# create world-writable FIFO; open O_RDWR so open() never blocks –
# fd 3 acts as a persistent writer keeping the pipe alive across restarts
rm -f /run/svc.log
mkfifo -m 0666 /run/svc.log
exec 3<>/run/svc.log
cat /run/svc.log &
_cat_pid=$!

_shutdown() {
  # stop all openrc services gracefully, ignore non-zero exit
  openrc shutdown || true
  kill "${_cat_pid}" 2>/dev/null || true
  # kill the sleep background job so the main loop exits immediately
  kill "${_sleep_pid}" 2>/dev/null || true
  exit 0
}
trap _shutdown TERM INT

# seed /config with default xfce4/gtk configs on first run
if [[ ! -f /config/.xdg-initialized ]]; then
  cp -rn /etc/xdg-obsidian/. /config/
  chown -R obsidian:obsidian /config
  touch /config/.xdg-initialized
fi

openrc default
# keep container alive – openrc exits after starting services;
# sleep in background so TERM/INT interrupts wait() immediately
_sleep_pid=0
while true; do
  sleep 60 &
  _sleep_pid=$!
  wait "${_sleep_pid}" || true
done
