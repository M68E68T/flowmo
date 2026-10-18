#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
# A malformed .strings file makes macOS display raw keys throughout the app.
for LANGUAGE in de en; do
  if ! plutil -lint "$PROJECT_ROOT/Resources/$LANGUAGE.lproj/Localizable.strings"; then
    printf 'Build abgebrochen: Die Sprachdatei für %s ist ungültig. Bitte den gemeldeten Syntaxfehler korrigieren.\n' "$LANGUAGE" >&2
    exit 1
  fi
done
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/ModuleCache"
swift build -c release --cache-path "$PROJECT_ROOT/.build/cache" --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security" "$@"
APP_PATH="$PROJECT_ROOT/dist/Flosted.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$PROJECT_ROOT/.build/release/Flosted" "$APP_PATH/Contents/MacOS/Flosted"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
# Render the shared vector artwork at every standard macOS icon resolution.
# The generator, PNGs and ICNS are build artifacts, never source assets.
ICON_BUILD="$PROJECT_ROOT/.build/branding"
mkdir -p "$ICON_BUILD"
swiftc -swift-version 5 -O -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  "$PROJECT_ROOT/Sources/Flosted/BrandMark.swift" \
  "$PROJECT_ROOT/scripts/GenerateAppIcon.swift" -o "$ICON_BUILD/generate-app-icon"
"$ICON_BUILD/generate-app-icon" "$ICON_BUILD/Flosted.iconset"
iconutil -c icns "$ICON_BUILD/Flosted.iconset" -o "$APP_PATH/Contents/Resources/Flosted.icns"
# Localizations: SwiftUI string literals resolve against Bundle.main.
# Lint first - macOS silently discards a malformed .strings file as a whole,
# and every label then falls back to showing its raw key.
for LPROJ in "$PROJECT_ROOT"/Resources/*.lproj; do
  [ -d "$LPROJ" ] || continue
  for STRINGS in "$LPROJ"/*.strings; do
    [ -f "$STRINGS" ] || continue
    if ! plutil -lint "$STRINGS" >/dev/null; then
      printf 'Fehlerhafte Ubersetzungsdatei: %s\n' "$STRINGS" >&2
      plutil -lint "$STRINGS" >&2 || true
      exit 1
    fi
  done
  cp -R "$LPROJ" "$APP_PATH/Contents/Resources/"
done
codesign --force --sign - "$APP_PATH"
printf 'App erstellt: %s\n' "$APP_PATH"
