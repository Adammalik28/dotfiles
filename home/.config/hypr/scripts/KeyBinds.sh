#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# searchable keybinds using rofi, read from the running Hyprland instance

# kill yad to not interfere with this binds
pkill yad || true

# check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

rofi_theme="$HOME/.config/rofi/config-keybinds.rasi"
msg='☣️ NOTE ☣️: Clicking with Mouse or Pressing ENTER will have NO function'

display_keybinds=$(hyprctl binds -j | jq -r '
  def mods($m):
    [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
    | map(select(($m / .[0] | floor) % 2 == 1) | .[1]);
  .[]
  | (if .key != "" then .key else "code:\(.keycode)" end) as $key
  | (if .has_description then .description
     else (.dispatcher | sub("^HL\\.Dispatcher\\("; "") | sub("\\)$"; "")) end) as $what
  | ((mods(.modmask) + [$key]) | join(" + ")) + "  →  " + $what
')

# use rofi to display the keybinds
printf '%s\n' "$display_keybinds" | rofi -dmenu -i -config "$rofi_theme" -mesg "$msg"
