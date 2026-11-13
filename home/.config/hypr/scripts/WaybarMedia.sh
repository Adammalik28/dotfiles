#!/usr/bin/env bash
# WaybarMedia.sh — "now playing" for Waybar (custom/media#mac)
# Shows only while a player is Playing (paused/stopped -> empty text, module hides).
# Strips the "(N) " unread-counter prefix browsers put in tab titles.

sep=$'\x1f'

emit() {
    local line player artist title text
    line=$(playerctl -a metadata --format "{{status}}${sep}{{playerName}}${sep}{{artist}}${sep}{{title}}" 2>/dev/null \
        | grep -m1 '^Playing')
    if [[ -z $line ]]; then
        echo '{"text":""}'
        return
    fi
    IFS=$sep read -r _ player artist title <<< "$line"
    title=$(sed -E 's/^\([0-9]+\) *//' <<< "$title")
    text=$title
    [[ -n $artist ]] && text="$title — $artist"
    jq -cn --arg t "󰎈  $text" --arg tt "$player · $text" '{text: $t, tooltip: $tt, class: "playing"}'
}

emit
# any status or track change on any player re-evaluates the whole picture
playerctl -a --follow metadata --format '{{status}}{{title}}' 2>/dev/null | while read -r _; do
    emit
done
