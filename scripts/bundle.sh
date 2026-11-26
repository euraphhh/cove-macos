#!/bin/bash
# Builds Cove.app (arm64, ad-hoc signed) into ./build
set -euo pipefail
cd "$(dirname "$0")/.."
# Local builds use the latest tag so Sparkle does not offer to "update" a dev build.
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed "s/^v//" || echo 0.0.0)}"
swift build -c release --arch arm64
APP=build/Cove.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS"
BINDIR="$(swift build -c release --arch arm64 --show-bin-path)"
cp "$BINDIR/Cove" "$APP/Contents/MacOS/Cove"
mkdir -p "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
ditto "$BINDIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
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
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>pt-BR</string></array>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>SUFeedURL</key><string>https://euraphhh.github.io/cove-macos/appcast.xml</string>
  <key>SUPublicEDKey</key><string>bnz+2yE/9pP72KHPNN/s0YzUvv3e+aHtXdon+7zTREA=</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>Cove shows an alert with battery level when your headphones connect.</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Cove shows your next meeting in the notch.</string>
  <key>NSAppleEventsUsageDescription</key><string>Cove shows and controls what is playing in Spotify and Music.</string>
</dict></plist>
PLIST
# Stable local identity keeps TCC permissions across rebuilds; falls back to ad-hoc (CI).
IDENTITY="-"
security find-identity -p codesigning 2>/dev/null | grep -q "Cove Dev" && IDENTITY="Cove Dev"
codesign --force --deep --sign "$IDENTITY" "$APP"
echo "Signed with: $IDENTITY"
echo "Built $APP"
