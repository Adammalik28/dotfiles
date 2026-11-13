#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For disabling touchpad.
# Edit the Touchpad_Device on ~/.config/hypr/UserConfigs/Laptops.conf according to your system
# use hyprctl devices to get your system touchpad device name
# source https://github.com/hyprwm/Hyprland/discussions/4283?sort=new#discussioncomment-8648109

set -euo pipefail

notif="$HOME/.config/swaync/images/ja.png"
laptops_conf="$HOME/.config/hypr/UserConfigs/Laptops.conf"

touchpad_device="${TOUCHPAD_DEVICE:-}"
if [[ -z "$touchpad_device" && -f "$laptops_conf" ]]; then
    touchpad_device="$(
        awk -F= '/^\$Touchpad_Device/ {
            gsub(/[[:space:]]*/, "", $1);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
            print $2;
            exit
        }' "$laptops_conf"
    )"
fi
if [[ -z "$touchpad_device" && -f "$HOME/.config/hypr/configs/Laptops.conf" ]]; then
    touchpad_device="$(
        awk -F= '/^\$Touchpad_Device/ {
            gsub(/[[:space:]]*/, "", $1);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
            print $2;
            exit
        }' "$HOME/.config/hypr/configs/Laptops.conf"
    )"
fi

if [[ -z "$touchpad_device" ]]; then
    notify-send -u low -i "$notif" " Touchpad" " Device name not set (check Laptops.conf)"
    exit 1
fi

mouse_companion="${touchpad_device%-touchpad}-mouse"
status_file="${XDG_RUNTIME_DIR:-/tmp}/touchpad.status"

set_device() {
    hyprctl eval "hl.device({ name = '$1', enabled = $2 })"
}

enable_touchpad() {
    printf "true" >"$status_file"
    notify-send -u low -i "$notif" " Enabling" " touchpad"
    set_device "$touchpad_device" true
    if [[ "$mouse_companion" != "$touchpad_device" ]]; then
        set_device "$mouse_companion" true || true
    fi
}

disable_touchpad() {
    printf "false" >"$status_file"
    notify-send -u low -i "$notif" " Disabling" " touchpad"
    set_device "$touchpad_device" false
    if [[ "$mouse_companion" != "$touchpad_device" ]]; then
        set_device "$mouse_companion" false || true
    fi
}

current_state="false"
if [[ -f "$status_file" ]]; then
    current_state="$(<"$status_file")"
fi

if [[ "$current_state" == "true" ]]; then
    disable_touchpad
else
    enable_touchpad
fi
