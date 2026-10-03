#!/usr/bin/env bash
# Low battery notifications for the laptop battery (20% warning, 10% critical).
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/battery-notify.lock"
flock -n 9 || exit 0

BAT=/sys/class/power_supply/BAT1
notified=100

while true; do
  cap=$(cat "$BAT/capacity" 2>/dev/null)
  status=$(cat "$BAT/status" 2>/dev/null)
  if [[ -n "$cap" ]]; then
    if [[ "$status" != Discharging ]]; then
      notified=100
    elif ((cap <= 10 && notified > 10)); then
      notify-send -u critical -i battery-caution "Baterai kritis: ${cap}%" "Segera colokkan charger!"
      notified=10
    elif ((cap <= 20 && notified > 20)); then
      notify-send -u normal -i battery-low "Baterai lemah: ${cap}%" "Sebaiknya colokkan charger."
      notified=20
    fi
  fi
  sleep 60
done
