#!/bin/bash
# Builds Cove.app, installs it to /Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -x Cove 2>/dev/null || true
./scripts/bundle.sh
rm -rf /Applications/Cove.app
cp -R build/Cove.app /Applications/
open /Applications/Cove.app
echo "Installed and launched /Applications/Cove.app"
