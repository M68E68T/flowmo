#!/bin/bash
# Builds the app and packs it for handing to someone else.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
# Friends may have Intel Macs: packages are universal unless told otherwise.
if [ "$#" -eq 0 ]; then set -- --arch arm64 --arch x86_64; fi
bash "$PROJECT_ROOT/scripts/build-app.sh" "$@"
APP_PATH="$PROJECT_ROOT/dist/FLowmo.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ZIP_PATH="$PROJECT_ROOT/dist/FLowmo-$VERSION.zip"
rm -f "$ZIP_PATH"
# ditto, not zip: it preserves the bundle structure and the code signature,
# which a plain zip quietly destroys.
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
codesign --verify --deep --strict "$APP_PATH"
printf 'Paket erstellt: %s (%s)\n' "$ZIP_PATH" "$(du -h "$ZIP_PATH" | cut -f1 | tr -d ' ')"
