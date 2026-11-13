#!/usr/bin/env bash
# WaybarPower.sh — macOS-style power dropdown for the waybar power button
# Lock / Sleep run immediately; Log Out, Restart and Shut Down ask for confirmation
# (Cancel is the default choice, so a stray Enter never shuts the machine down).

source "$(dirname "$(readlink -f "$0")")/MacMenuLib.sh"

# clicking the button again closes the menu
pkill -x rofi && exit 0

LOCK=$'\U000f033e  Lock Screen'
SLEEP=$'\U000f0904  Sleep'
LOGOUT=$'\U000f0343  Log Out…'
RESTART=$'\U000f0709  Restart…'
SHUTDOWN=$'\U000f0425  Shut Down…'

# small menu: no search box, narrow
menu() { mac_menu -no-custom -theme-str 'window { width: 230px; } inputbar { enabled: false; } listview { lines: 5; }' "$@"; }

confirm() {   # confirm "Shut Down" -> returns 0 only when the user picks the action
    local action=$1 choice
    choice=$(printf '%s\n' "Cancel" "$action" | menu -p "$action?" -mesg "Unsaved work in open apps may be lost.")
    [[ $choice == "$action" ]]
}

choice=$(printf '%s\n' "$LOCK" "$SLEEP" "$LOGOUT" "$RESTART" "$SHUTDOWN" | menu -p "Power")

case $choice in
    "$LOCK")     exec "$HOME/.config/hypr/scripts/LockScreen.sh" ;;
    "$SLEEP")    systemctl suspend ;;
    "$LOGOUT")   confirm "Log Out"   && hyprctl dispatch 'hl.dsp.exit()' ;;
    "$RESTART")  confirm "Restart"   && systemctl reboot ;;
    "$SHUTDOWN") confirm "Shut Down" && systemctl poweroff ;;
esac
