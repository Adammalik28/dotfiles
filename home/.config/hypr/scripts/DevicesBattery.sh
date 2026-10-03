#!/usr/bin/env bash
# Waybar: battery of wireless peripherals (mouse, keyboard) from /sys/class/power_supply.
# Shows only icons; adds the level when a device is low. Hidden when no device is connected.

icons="" tooltip="" low=0

for d in /sys/class/power_supply/*; do
  [[ "$(cat "$d/scope" 2>/dev/null)" == Device && "$(cat "$d/type" 2>/dev/null)" == Battery ]] || continue
  name=$(cat "$d/model_name" 2>/dev/null)
  cap=$(cat "$d/capacity" 2>/dev/null)
  lvl=$(cat "$d/capacity_level" 2>/dev/null)
  [[ -z "$cap" && -z "$lvl" ]] && continue

  case "${name,,}" in
    *mouse* | *g304* | *mx\ master* | *m3[0-9][0-9]*) icon="󰍽" ;;
    *keyboard* | *k380* | *k[0-9][0-9][0-9]*) icon="󰌌" ;;
    *headset* | *head* | *buds* | *airpods*) icon="󰋋" ;;
    *) icon="󰂯" ;;
  esac

  if [[ -n "$cap" ]]; then
    value="${cap}%"
    ((cap <= 20)) && is_low=1 || is_low=0
  else
    value="$lvl"
    [[ "$lvl" == Low || "$lvl" == Critical ]] && is_low=1 || is_low=0
  fi

  if ((is_low)); then
    icons+="$icon $value "
    low=1
  else
    icons+="$icon "
  fi
  tooltip+="$icon  ${name:-Unknown}: $value\\n"
done

[[ -z "$icons" ]] && { echo '{"text": ""}'; exit 0; }

class=$([[ $low == 1 ]] && echo low || echo normal)
printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "${icons% }" "${tooltip%\\n}" "$class"
