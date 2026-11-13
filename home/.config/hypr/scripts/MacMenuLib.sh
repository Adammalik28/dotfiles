#!/usr/bin/env bash
# MacMenuLib.sh — shared helper for the macOS-style rofi dropdowns (source it, don't run it)
# Picks the dark or light colours to match the system mode that DarkLight.sh sets in gsettings.
# Override for testing: MAC_MENU_MODE=light|dark

MAC_MENU_THEME="$HOME/.config/rofi/mac-menu.rasi"

mac_menu_mode() {
    if [[ -n ${MAC_MENU_MODE:-} ]]; then echo "$MAC_MENU_MODE"; return; fi
    [[ $(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null) == *light* ]] && echo light || echo dark
}

# usage: printf '%s\n' items | mac_menu -p "Prompt" [more rofi args]
mac_menu() {
    local extra=()
    if [[ $(mac_menu_mode) == light ]]; then
        extra=(-theme-str '* { bg: rgba(228,228,233,0.95); fg: rgba(28,28,30,0.95); fg-dim: rgba(44,44,50,0.68); line: rgba(0,0,0,0.14); }')
    fi
    rofi -dmenu -i -theme "$MAC_MENU_THEME" "${extra[@]}" "$@"
}
