#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# SUPER+ALT+O — toggle between two looks:
#   Normal Blur : windows fully opaque (no transparency)
#   Less Blur   : windows translucent (per-app opacity rules + kitty 0.88)
# State lives in UserConfigs/BlurMode.lua (loaded by hyprland.lua) so it
# survives `hyprctl reload` and relogin; kitty gets the same via kitty/blur-mode.conf.

notif="$HOME/.config/swaync/images"
mode_file="$HOME/.config/hypr/UserConfigs/BlurMode.lua"
kitty_file="$HOME/.config/kitty/blur-mode.conf"

if grep -q '^-- mode: normal' "$mode_file" 2>/dev/null; then
	new=less
	cat > "$mode_file" <<'EOF'
-- mode: less
-- Managed by scripts/ChangeBlur.sh (SUPER+ALT+O) -- don't edit by hand.
hl.config({ decoration = { blur = { size = 2, passes = 1 } } })
EOF
	echo "background_opacity 0.88" > "$kitty_file"
	msg=" Less Blur (transparent)"; icon="$notif/note.png"
else
	new=normal
	cat > "$mode_file" <<'EOF'
-- mode: normal
-- Managed by scripts/ChangeBlur.sh (SUPER+ALT+O) -- don't edit by hand.
hl.config({ decoration = { blur = { size = 5, passes = 2 } } })
hl.window_rule({ match = { class = ".*" }, opacity = "1.0 override 1.0 override" })
EOF
	echo "background_opacity 1.0" > "$kitty_file"
	msg=" Normal Blur (opaque)"; icon="$notif/ja.png"
fi

hyprctl reload >/dev/null 2>&1
pkill -USR1 -x kitty 2>/dev/null   # reload running kitty windows
notify-send -e -u low -i "$icon" "$msg"
