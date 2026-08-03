#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

OUT="${1:-$ROOT/dist}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
APP="$OUT/Lazy Starter Kit Installer.app"
CONTENTS="$APP/Contents"
[[ ! -e "$APP" ]] || safe_rm_rf_under "$OUT" "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

xcrun swiftc \
  -framework AppKit \
  -framework Foundation \
  "$ROOT/gui/macos/main.swift" \
  -o "$CONTENTS/MacOS/LazyStarterKitInstaller"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>ko</string>
  <key>CFBundleDisplayName</key><string>Lazy Starter Kit Installer</string>
  <key>CFBundleExecutable</key><string>LazyStarterKitInstaller</string>
  <key>CFBundleIdentifier</key><string>dev.cmore.lazy-starter-kit.installer</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Lazy Starter Kit Installer</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

printf 'Built %s\n' "$APP"
