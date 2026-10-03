#!/usr/bin/env bash
# Waybar: number of pending Arch updates (pacman + AUR via yay/paru). Hidden when 0.
repo=$(checkupdates 2>/dev/null | wc -l)
aur=0
if command -v yay >/dev/null; then aur=$(yay -Qua 2>/dev/null | wc -l)
elif command -v paru >/dev/null; then aur=$(paru -Qua 2>/dev/null | wc -l); fi
total=$((repo + aur))
((total == 0)) && { echo '{"text": ""}'; exit 0; }
printf '{"text": "%s", "tooltip": "Updates available\\nRepo: %s\\nAUR: %s\\n\\nClick: update system", "class": "pending"}\n' "$total" "$repo" "$aur"
