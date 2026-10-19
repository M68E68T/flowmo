#!/bin/bash
# Regenerates Resources/flowmo.icns from the BrandMark vectors in the app.
# Run after changing BrandMark; the resulting .icns is committed so a normal
# build never has to produce it.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
ICONSET="$PROJECT_ROOT/.build/flowmo.iconset"
rm -rf "$ICONSET"
swift build -c release --cache-path "$PROJECT_ROOT/.build/cache" \
  --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security" "$@"
"$PROJECT_ROOT/.build/release/flowmo" --export-iconset "$ICONSET"
iconutil --convert icns "$ICONSET" --output "$PROJECT_ROOT/Resources/flowmo.icns"
rm -rf "$ICONSET"
printf 'Icon erstellt: %s\n' "$PROJECT_ROOT/Resources/flowmo.icns"
