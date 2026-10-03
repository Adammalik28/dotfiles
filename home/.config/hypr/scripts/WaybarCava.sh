#!/usr/bin/env bash
# WaybarCava.sh — Visualizer audio untuk Waybar (custom/cava_mviz)
# Membutuhkan: cava
#
# Cara pasang:
#   mkdir -p ~/.config/hypr/scripts
#   cp WaybarCava.sh ~/.config/hypr/scripts/WaybarCava.sh
#   chmod +x ~/.config/hypr/scripts/WaybarCava.sh
#   pkill waybar; waybar & disown

set -euo pipefail

# Karakter batang, dari pendek ke tinggi (8 level, sesuai ascii_max_range di bawah)
bars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

cava_cfg="/tmp/waybar_cava_config"

# Kill cava left over from a previous waybar instance, and our own cava when waybar stops us
pkill -f "cava -p $cava_cfg" 2>/dev/null || true
trap 'pkill -P $$ 2>/dev/null; pkill -f "cava -p $cava_cfg" 2>/dev/null' EXIT INT TERM HUP

cat > "$cava_cfg" <<EOF
[general]
mode = normal
bars = 12
framerate = 30

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59

[smoothing]
noise_reduction = 20
EOF

cava -p "$cava_cfg" 2>/tmp/waybar_cava_error.log | while IFS= read -r line; do
    out=""
    IFS=';' read -ra values <<< "$line"
    for v in "${values[@]}"; do
        [[ -z "$v" ]] && continue
        # klem nilai ke rentang index array bars
        (( v < 0 )) && v=0
        (( v > 7 )) && v=7
        out+="${bars[$v]}"
    done
    printf '{"text":"%s","tooltip":"Cava Visualizer","class":"cava"}\n' "$out"
done
