#!/bin/bash
# Records README GIFs of the island using the debug hooks.
# Needs: debugHooks enabled (defaults write com.euraphhh.cove debugHooks -bool true), ffmpeg,
# Screen Recording permission for the terminal. Usage: scripts/record-demo.sh <music|alerts>
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="${1:-alerts}"
TMP=$(mktemp -d)
swiftc -O scripts/debug.swift -o "$TMP/coved" 2>/dev/null
SCREEN_W=$(osascript -e 'tell application "Finder" to get item 3 of (get bounds of window of desktop)')
MID=$((SCREEN_W / 2))

case "$NAME" in
  music)   # Start playing a song first.
    W=480; H=180; SECS=8
    (screencapture -v -V $SECS -x -R $((MID - W / 2)),0,$W,$H "$TMP/rec.mov" &)
    sleep 1.5; "$TMP/coved" close; sleep 1.5; "$TMP/coved" expand; sleep 3; "$TMP/coved" close ;;
  alerts)
    W=290; H=44; SECS=14
    (screencapture -v -V $SECS -x -R $((MID - W / 2)),0,$W,$H "$TMP/rec.mov" &)
    sleep 1.2
    for c in charging unlock lowBattery timer; do "$TMP/coved" $c; sleep 3; done
    "$TMP/coved" noTimer ;;
esac
sleep 3
mkdir -p docs
ffmpeg -loglevel error -y -i "$TMP/rec.mov" \
  -vf "fps=20,scale=iw/2*2:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
  "docs/$NAME.gif"
rm -rf "$TMP"
echo "Wrote docs/$NAME.gif"
