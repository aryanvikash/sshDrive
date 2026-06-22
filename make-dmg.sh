#!/bin/bash
# Builds the app and packages it into a shareable .dmg with a
# drag-to-Applications layout. No Xcode required.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Shell Drive"
APP="$APP_NAME.app"
DMG="$APP_NAME.dmg"

# 1) Build the .app bundle.
./build.sh

# 2) Stage a folder containing the app + an /Applications shortcut.
STAGE="$(mktemp -d)/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# 3) Create a compressed DMG from the staging folder.
echo "→ Creating ${DMG} …"
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

rm -rf "$STAGE"
SIZE="$(du -h "$DMG" | cut -f1)"
echo "✅ Done: $(pwd)/$DMG ($SIZE)"
echo "   Share it — users drag $APP_NAME into Applications."