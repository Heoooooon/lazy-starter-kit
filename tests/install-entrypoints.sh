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
  '[[ -z "${STARTER_KIT_PAYLOAD_MARKER:-}" ]] || printf "ran\n" > "$STARTER_KIT_PAYLOAD_MARKER"' \
  'printf "payload:%s\n" "$*"' \
  'printf "payload-final\n"' > "$TMP/payload.sh"

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
brand_source="$(<"$ROOT/gui/macos/Brand.swift")"
[[ "$macos_source" != *"window.contentView = content"* ]] \
  || fail "macOS GUI constrains its content stack to itself and launches blank"
[[ "$macos_source" != *"window.contentView = root"* ]] \
  || fail "macOS GUI replaces its sized content view with a zero-frame root"
[[ "$macos_source" == *"root.addSubview(content)"* ]] \
  || fail "macOS GUI does not attach its content stack to a persistent root view"
[[ "$macos_source" == *"log.textColor = .labelColor"* ]] \
  || fail "macOS GUI log text does not adapt to dark and light appearances"
[[ "$macos_source" != *"NSTextView"* ]] \
  || fail "macOS GUI still uses the notarization-sensitive NSTextView log"
[[ "$macos_source" == *"private let log = NSTextField()"* ]] \
  || fail "macOS GUI does not use a native multi-line text field for logs"
[[ "$macos_source" == *"log.isSelectable = true"* ]] \
  || fail "macOS GUI replacement log does not support selection and copy"
[[ "$macos_source" == *"log.stringValue.append(text)"* ]] \
  || fail "macOS GUI does not append execution output through the text field contract"
[[ "$macos_source" == *"self?.scrollLogToBottom()"* ]] \
  || fail "macOS GUI does not scroll the replacement log after layout"
[[ "$macos_source" == *"logScroll.contentView.scroll(to: .zero)"* ]] \
  || fail "macOS GUI does not account for the log document coordinate direction"
[[ "$macos_source" == *"controls.widthAnchor.constraint(equalTo: setupContent.widthAnchor)"* ]] \
  || fail "macOS GUI setup controls do not fill their card width"
[[ "$macos_source" == *"logViewport.widthAnchor.constraint(equalTo: logContent.widthAnchor)"* ]] \
  || fail "macOS GUI replacement log does not fill its card width"
[[ "$macos_source" == *"private let logEmptyState = NSTextField("* ]] \
  || fail "macOS GUI does not separate its initial guidance from execution logs"
[[ "$macos_source" == *"logEmptyState.isHidden = true"* ]] \
  || fail "macOS GUI does not hide initial guidance when execution begins"
[[ "$macos_source" == *'systemSymbolName: "terminal.fill"'* ]] \
  || fail "macOS GUI does not expose a recognizable log icon"
[[ "$macos_source" == *'systemSymbolName: "checkmark.shield.fill"'* ]] \
  || fail "macOS GUI does not expose its signed installer trust state"
[[ "$macos_source" == *"NSVisualEffectView"* ]] \
  || fail "macOS GUI does not use a native adaptive material surface"
[[ "$brand_source" == *'NSColor(name: "BrandMint")'* ]] \
  || fail "macOS GUI brand colors do not adapt to the current appearance"
[[ "$brand_source" == *"if size > 32"* ]] \
  || fail "macOS GUI icon does not simplify at small sizes"

# Given the GUI source, when its build script runs, then it creates a native
# application bundle whose binary exposes a deterministic self-test contract.
DIST="$TMP/dist"
bash "$ROOT/gui/macos/build-app.sh" "$DIST"
APP="$DIST/Lazy Starter Kit Installer.app"
[[ -x "$APP/Contents/MacOS/LazyStarterKitInstaller" ]] \
  || fail "macOS GUI app executable was not built"
[[ -f "$APP/Contents/Resources/AppIcon.icns" ]] \
  || fail "macOS GUI bundle does not contain its application icon"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist")" == "AppIcon" ]] \
  || fail "macOS GUI bundle does not declare its application icon"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMultipleInstancesProhibited' "$APP/Contents/Info.plist" 2>/dev/null)" == "true" ]] \
  || fail "macOS GUI bundle permits duplicate application instances"
deployment_target="$(
  xcrun vtool -show-build "$APP/Contents/MacOS/LazyStarterKitInstaller" \
    | awk '$1 == "minos" { print $2 }'
)"
[[ "$deployment_target" == "14.0" ]] \
  || fail "macOS GUI binary targets $deployment_target instead of macOS 14.0"
iconutil -c iconset "$APP/Contents/Resources/AppIcon.icns" -o "$TMP/AppIcon.iconset"
[[ "$(sips -g pixelWidth "$TMP/AppIcon.iconset/icon_16x16.png" | awk '/pixelWidth/ {print $2}')" == "16" ]] \
  || fail "macOS GUI bundle does not contain a native 16 px icon representation"
self_test="$("$APP/Contents/MacOS/LazyStarterKitInstaller" --self-test)"
[[ "$self_test" == *'"profiles":["full","minimal","work"]'* ]] \
  || fail "macOS GUI self-test did not expose all supported profiles"
[[ "$self_test" == *'"full":["prereqs","brew","runtimes","shell","docker","git","agents"]'* ]] \
  || fail "macOS GUI full profile does not match the installer steps"
[[ "$self_test" == *'"minimal":["prereqs","brew","runtimes","shell","git"]'* ]] \
  || fail "macOS GUI minimal profile does not match the installer steps"
[[ "$self_test" == *'"work":["prereqs","brew","runtimes","shell","git","agents"]'* ]] \
  || fail "macOS GUI work profile does not match the installer steps"
[[ "$self_test" == *'"supportsDryRun":true'* ]] \
  || fail "macOS GUI self-test did not expose dry-run support"
[[ "$self_test" == *'"supportsCustomSelection":true'* ]] \
  || fail "macOS GUI self-test did not expose component selection"
[[ "$self_test" == *'"supportsRepeatApply":true'* ]] \
  || fail "macOS GUI self-test did not expose repeat-apply support"
[[ "$self_test" == *'"toolsURL":"https:\/\/cmore.dev\/lazy-starter-kit\/tools\/"'* ]] \
  || fail "macOS GUI self-test did not expose the CMORE tool guide"
[[ "$self_test" == *'"hasApplicationIcon":true'* ]] \
  || fail "macOS GUI self-test did not expose its icon contract"
[[ "$self_test" == *'"interfaceVersion":3'* ]] \
  || fail "macOS GUI self-test did not expose the redesigned interface version"
[[ "$self_test" == *'"supportsAppearanceSnapshots":true'* ]] \
  || fail "macOS GUI self-test did not expose light and dark appearance QA"
MIN_SNAPSHOT="$TMP/minimum-window.png"
"$APP/Contents/MacOS/LazyStarterKitInstaller" --snapshot-size "$MIN_SNAPSHOT" 700 695
[[ "$(sips -g pixelWidth "$MIN_SNAPSHOT" | awk '/pixelWidth/ {print $2}')" == "700" ]] \
  || fail "macOS GUI minimum-width snapshot was not rendered"
[[ "$(sips -g pixelHeight "$MIN_SNAPSHOT" | awk '/pixelHeight/ {print $2}')" == "695" ]] \
  || fail "macOS GUI minimum-height snapshot was not rendered"
printf 'ok   macOS GUI app builds and reports its contract\n'

# Given a harmless local payload, when the real GUI auto-starts for E2E QA,
# then the window/controller/download/process path completes successfully.
GUI_RESULT="$TMP/gui-result.txt"
GUI_LOG_RESULT="$TMP/gui-log-result.txt"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_RESULT="$GUI_RESULT" \
STARTER_KIT_GUI_LOG_RESULT="$GUI_LOG_RESULT" \
  "$APP/Contents/MacOS/LazyStarterKitInstaller"
[[ -f "$GUI_RESULT" ]] || fail "macOS GUI did not emit its completion signal"
IFS= read -r gui_status < "$GUI_RESULT"
[[ "$gui_status" == "0" ]] \
  || fail "macOS GUI installer path did not complete successfully"
gui_action="$(sed -n '3p' "$GUI_RESULT")"
[[ "$gui_action" == "start-install" ]] \
  || fail "macOS GUI preview completion does not offer the installation action"
grep -qxF "payload-final" "$GUI_LOG_RESULT" \
  || fail "macOS GUI dropped the payload's final log output"
grep -qxF "payload:--yes --only prereqs,brew,runtimes,shell,docker,git,agents --dry-run" \
  "$GUI_LOG_RESULT" \
  || fail "macOS GUI did not pass the selected full component set"
printf 'ok   macOS GUI runs a payload through its real controller\n'

# Given the minimal preset, when the GUI starts a preview, then only that
# preset's component steps are passed to the installer.
MINIMAL_RESULT="$TMP/gui-minimal-result.txt"
MINIMAL_LOG_RESULT="$TMP/gui-minimal-log-result.txt"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_GUI_PROFILE=minimal \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_RESULT="$MINIMAL_RESULT" \
STARTER_KIT_GUI_LOG_RESULT="$MINIMAL_LOG_RESULT" \
  "$APP/Contents/MacOS/LazyStarterKitInstaller"
IFS= read -r minimal_status < "$MINIMAL_RESULT"
[[ "$minimal_status" == "0" ]] \
  || fail "macOS GUI minimal component preview did not complete"
grep -qxF "payload:--yes --only prereqs,brew,runtimes,shell,git --dry-run" \
  "$MINIMAL_LOG_RESULT" \
  || fail "macOS GUI did not pass the selected minimal component set"
printf 'ok   macOS GUI passes custom component selections\n'

# Given a standard user account, when an actual install is requested, then the
# GUI must explain the administrator requirement before running the payload.
BLOCKED_RESULT="$TMP/gui-blocked-result.txt"
BLOCKED_MARKER="$TMP/gui-blocked-payload-ran"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_PAYLOAD_MARKER="$BLOCKED_MARKER" \
STARTER_KIT_GUI_ADMIN_STATUS=0 \
STARTER_KIT_GUI_DRY_RUN=0 \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_RESULT="$BLOCKED_RESULT" \
  "$APP/Contents/MacOS/LazyStarterKitInstaller"
IFS= read -r blocked_status < "$BLOCKED_RESULT"
[[ "$blocked_status" == "77" ]] \
  || fail "macOS GUI did not stop a non-administrator actual install"
blocked_action="$(sed -n '3p' "$BLOCKED_RESULT")"
[[ "$blocked_action" == "administrator-required" ]] \
  || fail "macOS GUI did not expose the administrator requirement"
blocked_guidance="$(sed -n '4p' "$BLOCKED_RESULT")"
[[ "$blocked_guidance" == "admin-account-required-no-password" ]] \
  || fail "macOS GUI did not expose credential-safe administrator guidance"
[[ ! -e "$BLOCKED_MARKER" ]] \
  || fail "macOS GUI ran the installer payload without administrator access"
printf 'ok   macOS GUI blocks actual installs for standard users\n'

# Given an administrator whose Mac still needs first-time prerequisites, when
# actual setup is requested, then the GUI must hand the selected steps to an
# interactive Terminal command without running the payload or storing secrets.
HANDOFF_RESULT="$TMP/gui-handoff-result.txt"
HANDOFF_MARKER="$TMP/gui-handoff-payload-ran"
HANDOFF_COMMAND="$TMP/lazy-starter-kit-handoff.command"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_PAYLOAD_MARKER="$HANDOFF_MARKER" \
STARTER_KIT_GUI_ADMIN_STATUS=1 \
STARTER_KIT_GUI_PREREQUISITES=missing-homebrew \
STARTER_KIT_GUI_DRY_RUN=0 \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_DISABLE_TERMINAL_OPEN=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_HANDOFF_PATH="$HANDOFF_COMMAND" \
STARTER_KIT_GUI_RESULT="$HANDOFF_RESULT" \
  "$APP/Contents/MacOS/LazyStarterKitInstaller"
IFS= read -r handoff_status < "$HANDOFF_RESULT"
[[ "$handoff_status" == "79" ]] \
  || fail "macOS GUI did not enter the first-time Terminal handoff state"
handoff_action="$(sed -n '3p' "$HANDOFF_RESULT")"
[[ "$handoff_action" == "terminal-required" ]] \
  || fail "macOS GUI did not expose the Terminal-required action"
handoff_guidance="$(sed -n '4p' "$HANDOFF_RESULT")"
[[ "$handoff_guidance" == "terminal-approval-required-no-password" ]] \
  || fail "macOS GUI did not expose credential-safe Terminal guidance"
[[ ! -e "$HANDOFF_MARKER" ]] \
  || fail "macOS GUI ran the payload before interactive prerequisites"
[[ -x "$HANDOFF_COMMAND" ]] \
  || fail "macOS GUI did not create an executable Terminal handoff"
grep -q -- "--only prereqs,brew,runtimes,shell,docker,git,agents" "$HANDOFF_COMMAND" \
  || fail "Terminal handoff lost the selected component steps"
if grep -Eqi 'password|sudo[[:space:]]+-S|SUDO_ASKPASS' "$HANDOFF_COMMAND"; then
  fail "Terminal handoff contains credential capture logic"
fi
printf 'ok   macOS GUI creates a credential-safe Terminal handoff\n'

# Given an administrator account and a harmless payload, when installation
# succeeds, then completion must expose the one remaining manual action.
INSTALL_RESULT="$TMP/gui-install-result.txt"
INSTALL_MARKER="$TMP/gui-install-payload-ran"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_PAYLOAD_MARKER="$INSTALL_MARKER" \
STARTER_KIT_GUI_ADMIN_STATUS=1 \
STARTER_KIT_GUI_PREREQUISITES=ready \
STARTER_KIT_GUI_DRY_RUN=0 \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_RESULT="$INSTALL_RESULT" \
  "$APP/Contents/MacOS/LazyStarterKitInstaller"
IFS= read -r install_status < "$INSTALL_RESULT"
[[ "$install_status" == "0" ]] \
  || fail "macOS GUI actual install path did not complete successfully"
install_action="$(sed -n '3p' "$INSTALL_RESULT")"
[[ "$install_action" == "open-new-terminal" ]] \
  || fail "macOS GUI completion did not expose the terminal reload action"
[[ -f "$INSTALL_MARKER" ]] \
  || fail "macOS GUI did not run the actual installer payload"
printf 'ok   macOS GUI exposes the post-install terminal action\n'

# Given component-specific Brewfiles, when Homebrew resolves each manifest,
# then core selection must not pull runtime or Docker packages.
full_bundle="$(brew bundle list --file="$ROOT/Brewfile")"
[[ "$full_bundle" == *$'docker'* && "$full_bundle" == *$'mise'* ]] \
  || fail "full Brewfile no longer includes Docker and runtime packages"
core_bundle="$(brew bundle list --file="$ROOT/Brewfile.core")"
[[ "$core_bundle" != *$'docker'* && "$core_bundle" != *$'colima'* ]] \
  || fail "core Brewfile unexpectedly includes Docker packages"
[[ "$core_bundle" != *$'mise'* && "$core_bundle" != *$'rustup'* ]] \
  || fail "core Brewfile unexpectedly includes runtime packages"
runtime_bundle="$(brew bundle list --file="$ROOT/Brewfile.runtimes")"
[[ "$runtime_bundle" == *$'mise'* && "$runtime_bundle" == *$'rustup'* ]] \
  || fail "runtime Brewfile does not contain its runtime packages"
docker_bundle="$(brew bundle list --file="$ROOT/Brewfile.docker")"
[[ "$docker_bundle" == *$'docker'* && "$docker_bundle" == *$'colima'* ]] \
  || fail "Docker Brewfile does not contain its container packages"
printf 'ok   Brewfile honors component selections\n'

printf 'PASS install entrypoints\n'
