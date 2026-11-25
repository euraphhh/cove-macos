#!/bin/bash
# Usage: appcast-item.sh <version> <zip> <appcast.xml>
# Signs the zip with the Sparkle EdDSA key from $SPARKLE_PRIVATE_KEY and inserts a new item.
set -euo pipefail
VERSION="$1"; ZIP="$2"; APPCAST="$3"
SIGN="$(echo "$SPARKLE_PRIVATE_KEY" | .build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file - "$ZIP")"
URL="https://github.com/euraphhh/cove-macos/releases/download/v${VERSION}/Cove.zip"
ITEM="    <item>
      <title>Version ${VERSION}</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/euraphhh/cove-macos/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <enclosure url=\"${URL}\" type=\"application/octet-stream\" ${SIGN} />
    </item>"
python3 - "$APPCAST" "$ITEM" <<'PY'
import sys
path, item = sys.argv[1], sys.argv[2]
s = open(path).read()
marker = "<language>en</language>"
s = s.replace(marker, marker + "\n" + item, 1)
open(path, "w").write(s)
PY
