#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
TMP_ROOT="$ROOT/.tmp-tests"
mkdir -p "$TMP_ROOT"
TMP="$(mktemp -d "$TMP_ROOT/install-entrypoints.XXXXXX")"
cleanup() {
  safe_rm_rf_under "$TMP_ROOT" "$TMP"
  rmdir "$TMP_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

printf '%s\n' '#!/usr/bin/env bash' \
  'printf "payload:%s\n" "$*"' > "$TMP/payload.sh"

# Given a local installer payload, when the Finder launcher runs, then it
# delegates every argument to that payload without requiring network access.
launcher_output="$(
  STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
  STARTER_KIT_NO_PAUSE=1 \
  "$ROOT/Install-lazy-starter-kit.command" --dry-run --profile minimal
)" || fail "macOS launcher did not execute the installer payload"
[[ "$launcher_output" == *"payload:--dry-run --profile minimal"* ]] \
  || fail "macOS launcher did not preserve installer arguments"
printf 'ok   macOS double-click launcher delegates arguments\n'

# Given a normal AppKit launch, when the window installs its content hierarchy,
# then the stack must be constrained to a persistent root view. Making the
# stack itself the content view creates self-referential constraints and a
# blank window until a test-only forced layout happens.
macos_source="$(<"$ROOT/gui/macos/main.swift")"
[[ "$macos_source" != *"window.contentView = content"* ]] \
  || fail "macOS GUI constrains its content stack to itself and launches blank"
[[ "$macos_source" != *"window.contentView = root"* ]] \
  || fail "macOS GUI replaces its sized content view with a zero-frame root"
[[ "$macos_source" == *"root.addSubview(content)"* ]] \
  || fail "macOS GUI does not attach its content stack to a persistent root view"
[[ "$macos_source" == *"log.textColor = .textColor"* ]] \
  || fail "macOS GUI log text does not adapt to dark and light appearances"

# Given the GUI source, when its build script runs, then it creates a native
# application bundle whose binary exposes a deterministic self-test contract.
DIST="$TMP/dist"
bash "$ROOT/gui/macos/build-app.sh" "$DIST"
APP="$DIST/Lazy Starter Kit Installer.app"
[[ -x "$APP/Contents/MacOS/LazyStarterKitInstaller" ]] \
  || fail "macOS GUI app executable was not built"
self_test="$("$APP/Contents/MacOS/LazyStarterKitInstaller" --self-test)"
[[ "$self_test" == *'"profiles":["full","minimal","work"]'* ]] \
  || fail "macOS GUI self-test did not expose all supported profiles"
[[ "$self_test" == *'"supportsDryRun":true'* ]] \
  || fail "macOS GUI self-test did not expose dry-run support"
printf 'ok   macOS GUI app builds and reports its contract\n'

# Given a harmless local payload, when the real GUI auto-starts for E2E QA,
# then the window/controller/download/process path completes successfully.
GUI_RESULT="$TMP/gui-result.txt"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_RESULT="$GUI_RESULT" \
  "$APP/Contents/MacOS/LazyStarterKitInstaller"
[[ -f "$GUI_RESULT" ]] || fail "macOS GUI did not emit its completion signal"
IFS= read -r gui_status < "$GUI_RESULT"
[[ "$gui_status" == "0" ]] \
  || fail "macOS GUI installer path did not complete successfully"
printf 'ok   macOS GUI runs a payload through its real controller\n'

printf 'PASS install entrypoints\n'
