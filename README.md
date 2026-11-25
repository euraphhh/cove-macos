# Cove

Dynamic Island-style app for the MacBook notch. Free, open source, Apple Silicon, macOS 14+.

## Build & run
```bash
./scripts/bundle.sh
open build/Cove.app
```
Quit with `pkill Cove`.

## Install from Releases
The app is **not notarized**. After downloading, run:
```bash
xattr -cr /Applications/Cove.app
```
or open it via System Settings > Privacy & Security > "Open Anyway".

## Status
- [x] Notch panel with hover expand/collapse
- [x] Media module (Spotify / Music via AppleScript)
- [ ] Shelf
- [ ] System HUD
- [ ] Settings + launch at login
