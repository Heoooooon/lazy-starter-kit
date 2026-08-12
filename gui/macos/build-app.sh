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

RELEASE_REF="${STARTER_KIT_RELEASE_REF:-}"
if [[ -z "$RELEASE_REF" ]]; then
  RELEASE_REF="$(git -C "$ROOT" describe --tags --exact-match HEAD 2>/dev/null || true)"
  [[ "$RELEASE_REF" == v* ]] || RELEASE_REF=main
fi
if [[ "$RELEASE_REF" == "main" ]]; then
  APP_VERSION=dev
  BUNDLE_VERSION=0
elif [[ "$RELEASE_REF" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  APP_VERSION="${RELEASE_REF#v}"
  BUNDLE_VERSION="$APP_VERSION"
else
  die "STARTER_KIT_RELEASE_REF must be main or a vMAJOR.MINOR.PATCH tag"
fi
DEVELOPER_MODE="${STARTER_KIT_DEVELOPER_MODE:-0}"
[[ "$DEVELOPER_MODE" == "0" || "$DEVELOPER_MODE" == "1" ]] \
  || die "STARTER_KIT_DEVELOPER_MODE must be 0 or 1"
if [[ "$DEVELOPER_MODE" == "1" ]]; then
  RELEASE_COMMIT="$(
    git -C "$ROOT" rev-parse --verify "${RELEASE_REF}^{commit}" 2>/dev/null \
      || git -C "$ROOT" rev-parse --verify 'HEAD^{commit}'
  )"
else
  RELEASE_COMMIT="$(git -C "$ROOT" rev-parse --verify "${RELEASE_REF}^{commit}")"
fi
[[ "$RELEASE_COMMIT" =~ ^[0-9a-f]{40}$ ]] \
  || die "Could not resolve an immutable release commit"
if [[ "$RELEASE_REF" != "main" ]]; then
  [[ "v$(<"$ROOT/VERSION")" == "$RELEASE_REF" ]] \
    || die "VERSION does not match STARTER_KIT_RELEASE_REF"
fi

BOOTSTRAP="$CONTENTS/Resources/install.sh"
cp "$ROOT/install.sh" "$BOOTSTRAP"
chmod 644 "$BOOTSTRAP"
BOOTSTRAP_SHA256="$(shasum -a 256 "$BOOTSTRAP" | awk '{print $1}')"

BUILD_INFO="$OUT/.LazyStarterKitBuildInfo.swift"
printf '%s\n' \
  'import Foundation' \
  '' \
  'enum BuildInfo {' \
  "  static let appVersion = \"$APP_VERSION\"" \
  "  static let developerMode = $([[ "$DEVELOPER_MODE" == "1" ]] && printf true || printf false)" \
  "  static let releaseCommit = \"$RELEASE_COMMIT\"" \
  "  static let releaseRef = \"$RELEASE_REF\"" \
  "  static let installerSHA256 = \"$BOOTSTRAP_SHA256\"" \
  '}' > "$BUILD_INFO"
cleanup_build_info() {
  rm -f "$BUILD_INFO" "$OUT/.LazyStarterKitInstaller-arm64" "$OUT/.LazyStarterKitInstaller-x86_64"
}
trap cleanup_build_info EXIT

for arch in arm64 x86_64; do
  xcrun swiftc \
    -target "$arch-apple-macosx14.0" \
    -framework AppKit \
    -framework CryptoKit \
    -framework Foundation \
    "$BUILD_INFO" \
    "$ROOT/gui/macos/Brand.swift" \
    "$ROOT/gui/macos/InstallerProcessSession.swift" \
    "$ROOT/gui/macos/main.swift" \
    -o "$OUT/.LazyStarterKitInstaller-$arch"
done
xcrun lipo -create \
  "$OUT/.LazyStarterKitInstaller-arm64" \
  "$OUT/.LazyStarterKitInstaller-x86_64" \
  -output "$CONTENTS/MacOS/LazyStarterKitInstaller"
cleanup_build_info
trap - EXIT

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

cat > "$CONTENTS/Info.plist" <<PLIST
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
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>$BUNDLE_VERSION</string>
  <key>LSMultipleInstancesProhibited</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

printf 'Built %s\n' "$APP"
