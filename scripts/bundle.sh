#!/bin/bash
# Builds Cove.app (arm64, ad-hoc signed) into ./build
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
swift build -c release --arch arm64
APP=build/Cove.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS"
cp .build/arm64-apple-macosx/release/Cove "$APP/Contents/MacOS/Cove"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.euraphhh.cove</string>
  <key>CFBundleName</key><string>Cove</string>
  <key>CFBundleExecutable</key><string>Cove</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Cove shows and controls what is playing in Spotify and Music.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "Built $APP"
