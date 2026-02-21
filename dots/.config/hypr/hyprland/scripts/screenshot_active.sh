#!/bin/bash

# Screenshot active monitor - save to file and copy to clipboard
# Usage: screenshot_active.sh [--satty]

SCREENSHOT_DIR="$HOME/Pictures/screenshots"
mkdir -p "$SCREENSHOT_DIR"

MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

if [[ "$1" == "--satty" ]]; then
    grim -o "$MONITOR" - | satty --filename -
else
    FILENAME="$SCREENSHOT_DIR/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png"
    grim -o "$MONITOR" "$FILENAME"
    wl-copy < "$FILENAME"
fi