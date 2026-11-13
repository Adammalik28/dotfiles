#!/usr/bin/env bash
# WaybarWifi.sh — macOS-style Wi-Fi dropdown (rofi + nmcli) for the waybar network icon
# Click a network to join it (asks for a password only when needed),
# click the connected one to disconnect, or open the full network settings.

source "$(dirname "$(readlink -f "$0")")/MacMenuLib.sh"

# clicking the icon again closes the menu
pkill -x rofi && exit 0

menu() { mac_menu "$@"; }
notify() { notify-send -a "Wi-Fi" -i network-wireless "$@" 2>/dev/null; }

SETTINGS="󰒓  Network Settings…"
RESCAN="󰑐  Scan Again"

if [[ $(nmcli radio wifi) != enabled ]]; then
    choice=$(printf '%s\n' "󰖩  Turn Wi-Fi On" "$SETTINGS" | menu -p "Wi-Fi" -mesg "Wi-Fi is off")
    case $choice in
        *"Turn Wi-Fi On") nmcli radio wifi on && notify "Wi-Fi turned on" ;;
        "$SETTINGS") nm-connection-editor & ;;
    esac
    exit 0
fi

rescan=${1:-no}   # first open uses the cached scan (instant); "Scan Again" forces a fresh one

rows=()     # what rofi shows
ssids=()    # SSID behind each row (same index)
secure=()   # 1 if the network needs a password
active_row=""
declare -A seen

# -t output: IN-USE:SIGNAL:SECURITY:SSID — SSID last so its (escaped) colons stay intact
while IFS= read -r line; do
    inuse=${line%%:*};  line=${line#*:}
    signal=${line%%:*}; line=${line#*:}
    sec=${line%%:*};    ssid=${line#*:}
    ssid=${ssid//\\:/:}; ssid=${ssid//\\\\/\\}
    [[ -z $ssid || -n ${seen[$ssid]} ]] && continue
    seen[$ssid]=1

    if   (( signal >= 75 )); then icon="󰤨"
    elif (( signal >= 50 )); then icon="󰤥"
    elif (( signal >= 25 )); then icon="󰤢"
    else                          icon="󰤟"; fi
    lock=""; is_secure=0
    if [[ -n $sec && $sec != "--" ]]; then lock="  󰌾"; is_secure=1; fi
    check="   "; [[ $inuse == "*" ]] && check="󰄬  " && active_row=${#rows[@]}

    rows+=("$check$icon  $ssid$lock")
    ssids+=("$ssid")
    secure+=("$is_secure")
done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan "$rescan" 2>/dev/null | sort -t: -k1,1r -k2,2nr)

# networks first (the default selection is never a destructive action), actions below
footer=("$RESCAN" "󰖪  Turn Wi-Fi Off" "$SETTINGS")

args=(-p "Wi-Fi" -format i -no-custom)
[[ -n $active_row ]] && args+=(-a "$active_row")
(( ${#rows[@]} == 0 )) && args+=(-mesg "No networks found")

idx=$(printf '%s\n' "${rows[@]}" "${footer[@]}" | menu "${args[@]}")
[[ -z $idx || $idx == -1 ]] && exit 0

if (( idx >= ${#rows[@]} )); then
    case $(( idx - ${#rows[@]} )) in
        0) notify "Scanning for networks…"; exec "$0" yes ;;
        1) nmcli radio wifi off && notify "Wi-Fi turned off" ;;
        2) nm-connection-editor & ;;
    esac
    exit 0
fi

i=$idx
ssid=${ssids[$i]}

# connected network -> offer disconnect
if [[ -n $active_row && $i -eq $active_row ]]; then
    choice=$(printf '%s\n' "󰖪  Disconnect" "Cancel" | menu -p "$ssid" -no-custom)
    if [[ $choice == *Disconnect ]]; then
        con=$(nmcli -t -f NAME,DEVICE con show --active | awk -F: '$2 ~ /^wl/ {print $1; exit}')
        nmcli con down id "$con" >/dev/null && notify "Disconnected from $ssid"
    fi
    exit 0
fi

# saved profile for this SSID? bring it up instead of creating a duplicate
saved=""
while IFS=: read -r name type; do
    [[ $type == 802-11-wireless ]] || continue
    if [[ $(nmcli -g 802-11-wireless.ssid con show "$name" 2>/dev/null) == "$ssid" ]]; then
        saved=$name; break
    fi
done < <(nmcli -t -f NAME,TYPE con show)

if [[ -n $saved ]]; then
    notify "Connecting to $ssid…"
    if nmcli con up id "$saved" >/dev/null 2>&1; then
        notify "Connected to $ssid"
        exit 0
    fi
    # keep the profile; if the network is secured the stored password may be stale, so ask once
    if (( ${secure[$i]} )); then
        pass=$(menu -p "Password" -password -mesg "Couldn't join “$ssid”. Re-enter the password" < /dev/null)
        [[ -z $pass ]] && exit 0
        if nmcli con modify id "$saved" wifi-sec.psk "$pass" && nmcli con up id "$saved" >/dev/null 2>&1; then
            notify "Connected to $ssid"
        else
            notify -u critical "Couldn't join $ssid" "Wrong password or network out of range."
        fi
    else
        notify -u critical "Couldn't join $ssid" "Network out of range?"
    fi
    exit 0
fi

if (( ${secure[$i]} )); then
    pass=$(menu -p "Password" -password -mesg "Enter the password for “$ssid”" < /dev/null)
    [[ -z $pass ]] && exit 0
    notify "Connecting to $ssid…"
    if nmcli dev wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
        notify "Connected to $ssid"
    else
        # remove only the half-made profile this attempt created (none was saved for this SSID)
        nmcli con delete id "$ssid" >/dev/null 2>&1
        notify -u critical "Couldn't join $ssid" "Wrong password or network out of range."
    fi
else
    notify "Connecting to $ssid…"
    nmcli dev wifi connect "$ssid" >/dev/null 2>&1 && notify "Connected to $ssid" \
        || notify -u critical "Couldn't join $ssid"
fi
