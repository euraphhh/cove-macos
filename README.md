# Cove

Dynamic Island-style app for the MacBook notch. Free, open source, Apple Silicon, macOS 14+.

## Build & run
```bash
./scripts/install.sh   # builds, installs to /Applications and launches
```
Quit from the menu bar icon (or `pkill Cove`).

## Install from Releases
The app is **not notarized**. After downloading, run:
```bash
xattr -cr /Applications/Cove.app
```
or open it via System Settings > Privacy & Security > "Open Anyway".

## Status
- [x] Notch panel with hover expand/collapse
- [x] Media module (Spotify / Music via AppleScript)
- [x] Shelf (drag files to the notch and back out)
- [ ] System HUD
- [x] Menu bar + Settings + launch at login
