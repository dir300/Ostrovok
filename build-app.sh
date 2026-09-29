#!/usr/bin/env bash
# Builds Ostrovok.app. SwiftPM alone produces a bare binary; we need a proper
# .app bundle for LSUIElement (menu-bar-only app) and TCC permissions to stick.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="build/Ostrovok.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Ostrovok"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ostrovok"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign with a developer identity rather than ad-hoc: TCC (Accessibility,
# Automation, etc.) keys permissions by signing identity instead of binary hash,
# so permissions survive rebuilds.
IDENTITY="${OSTROVOK_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
    | awk '/Apple Development/ { print $2; exit }')}"

if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP" >/dev/null
else
    echo "warning: no developer identity; ad-hoc signing (permissions reset each rebuild)" >&2
    codesign --force --sign - "$APP" >/dev/null
fi

echo "done: $APP"
