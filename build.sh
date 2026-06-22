#!/bin/bash
# Builds "Shell Drive.app" using the Swift compiler + macOS SDK (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")"

APP="Shell Drive.app"
BIN="ShellDrive"

echo "→ Cleaning previous build…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ Copying Info.plist…"
cp Info.plist "$APP/Contents/Info.plist"

# Generate the .icns if missing, then bundle it.
if [ ! -f ShellDrive.icns ]; then
    echo "→ Generating app icon…"
    swift gen-icon.swift ShellDrive.iconset
    iconutil -c icns ShellDrive.iconset -o ShellDrive.icns
    rm -rf ShellDrive.iconset
fi
cp ShellDrive.icns "$APP/Contents/Resources/ShellDrive.icns"

echo "→ Compiling Swift sources…"
# Sources are organized into subdirectories; compile them all together.
SOURCES=$(find Sources -name '*.swift')
swiftc -O \
    -o "$APP/Contents/MacOS/$BIN" \
    $SOURCES \
    -framework SwiftUI \
    -framework AppKit \
    -framework Carbon \
    -framework ServiceManagement

echo "→ Ad-hoc code signing (stable identity for Accessibility permission)…"
codesign --force --deep --sign - --identifier com.shelldrive.app "$APP"

echo "✅ Built: $APP"
echo "   Run with:  open \"$APP\"   (or)   ./\"$APP/Contents/MacOS/$BIN\""
