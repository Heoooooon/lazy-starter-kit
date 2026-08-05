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
  "$ROOT/gui/macos/Brand.swift" \
  "$ROOT/gui/macos/main.swift" \
  -o "$CONTENTS/MacOS/LazyStarterKitInstaller"

ICONSET="$OUT/LazyStarterKit.iconset"
[[ ! -e "$ICONSET" ]] || safe_rm_rf_under "$OUT" "$ICONSET"
mkdir -p "$ICONSET"
cleanup_iconset() {
  [[ ! -e "$ICONSET" ]] || safe_rm_rf_under "$OUT" "$ICONSET"
}
trap cleanup_iconset EXIT

render_icon() {
  local target="$1"
  local size="$2"
  local raw="$ICONSET/.${target##*/}.raw.png"
  "$CONTENTS/MacOS/LazyStarterKitInstaller" --render-icon "$raw" "$size"
  sips -z "$size" "$size" "$raw" --out "$target" >/dev/null
  rm "$raw"
}

render_icon "$ICONSET/icon_16x16.png" 16
render_icon "$ICONSET/icon_16x16@2x.png" 32
render_icon "$ICONSET/icon_32x32.png" 32
render_icon "$ICONSET/icon_32x32@2x.png" 64
render_icon "$ICONSET/icon_128x128.png" 128
render_icon "$ICONSET/icon_128x128@2x.png" 256
render_icon "$ICONSET/icon_256x256.png" 256
render_icon "$ICONSET/icon_256x256@2x.png" 512
render_icon "$ICONSET/icon_512x512.png" 512
render_icon "$ICONSET/icon_512x512@2x.png" 1024
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
cleanup_iconset
trap - EXIT

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
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

printf 'Built %s\n' "$APP"
