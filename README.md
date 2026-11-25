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
- [x] Compact live activities (music, timer) with island-style animations
- [x] Alerts: charger, headphones (with battery)
- [x] Volume/brightness HUD (optional, needs Accessibility)
- [x] Timer (menu bar > Timer)
- [x] Upcoming meeting with Join button (menu bar > Show Upcoming Meetings)
- [x] Low battery alert
- [x] Menu bar + Settings + launch at login
