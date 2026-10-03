#!/usr/bin/env bash
# Restart waybar if it dies (e.g. crash while the laptop is idle).
# Checks twice before relaunching so it doesn't race with Refresh.sh / WaybarStyles.sh,
# which kill and restart waybar themselves.

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-watchdog.lock"
flock -n 9 || exit 0 # only one watchdog

sleep 10 # let exec-once start waybar first

while true; do
  if ! pgrep -x waybar >/dev/null; then
    sleep 3
    if ! pgrep -x waybar >/dev/null; then
      waybar >/dev/null 2>&1 &
      disown
    fi
  fi
  sleep 5
done
