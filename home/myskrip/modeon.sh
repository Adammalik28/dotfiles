#!/bin/bash

# Workspace 1
hyprctl dispatch workspace 1
sleep 0.5

wasistlos &
sleep 2

whatsie &
sleep 1

# Workspace 2
hyprctl dispatch workspace 2
sleep 0.5

firefox \
    "https://www.youtube.com" \
    "https://www.instagram.com" \
    "https://x.com" \
    "https://www.facebook.com" \
    "https://chatgpt.com" \
    "https://gemini.google.com" &

exit 0
