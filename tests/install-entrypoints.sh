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

# shellcheck disable=SC2016
printf '%s\n' '#!/usr/bin/env bash' \
  '[[ -z "${STARTER_KIT_PAYLOAD_MARKER:-}" ]] || printf "ran\n" > "$STARTER_KIT_PAYLOAD_MARKER"' \
  'printf "starter-dir:%s\n" "${STARTER_KIT_DIR:-}"' \
  'printf "payload:%s\n" "$*"' \
  'printf "payload-final\n"' > "$TMP/payload.sh"
PAYLOAD_SHA256="$(shasum -a 256 "$TMP/payload.sh" | awk '{print $1}')"

# Given a local installer payload, when the Finder launcher runs, then it
# delegates every argument to that payload without requiring network access.
launcher_output="$(
  STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
  STARTER_KIT_INSTALL_SHA256="$PAYLOAD_SHA256" \
  STARTER_KIT_LAUNCHER_DEVELOPER_MODE=1 \
  STARTER_KIT_NO_PAUSE=1 \
  "$ROOT/Install-lazy-starter-kit.command" --dry-run --profile minimal
)" || fail "macOS launcher did not execute the installer payload"
[[ "$launcher_output" == *"payload:--dry-run --profile minimal"* ]] \
  || fail "macOS launcher did not preserve installer arguments"
printf 'ok   macOS double-click launcher delegates arguments\n'

# Given the trailing slash used by macOS TMPDIR, when the packaged launcher
# creates its ephemeral checkout path, then the path must not contain an empty
# component that safe recursive cleanup will reject.
PACKAGED_LAUNCHER="$TMP/macos-package"
mkdir -p "$PACKAGED_LAUNCHER" "$TMP/tmp-root"
cp "$ROOT/Install-lazy-starter-kit.command" "$PACKAGED_LAUNCHER/"
cp "$TMP/payload.sh" "$PACKAGED_LAUNCHER/install.sh"
printf '0.12.0\n' > "$PACKAGED_LAUNCHER/VERSION"
printf '0000000000000000000000000000000000000000\n' > "$PACKAGED_LAUNCHER/RELEASE_COMMIT"
PAYLOAD_SHA256="$PAYLOAD_SHA256" perl -0pi -e \
  's/__BOOTSTRAP_SHA256__/$ENV{PAYLOAD_SHA256}/g' \
  "$PACKAGED_LAUNCHER/Install-lazy-starter-kit.command"
packaged_output="$(
  TMPDIR="$TMP/tmp-root/" \
  STARTER_KIT_NO_PAUSE=1 \
    "$PACKAGED_LAUNCHER/Install-lazy-starter-kit.command" --dry-run
)" || fail "packaged macOS launcher did not execute its bundled payload"
starter_dir="$(
  printf '%s\n' "$packaged_output" | awk -F: '/^starter-dir:/{print substr($0, 13); exit}'
)"
[[ -n "$starter_dir" && "$starter_dir" != *"//"* ]] \
  || fail "macOS launcher created an unsafe ephemeral path: $starter_dir"
printf 'ok   macOS launcher normalizes its temporary checkout path\n'

# Given an existing bootstrap checkout, when the requested ref cannot prove the
# pinned commit or the checkout is dirty, then installation must fail closed.
PINNED_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
BOOTSTRAP_CHECKOUT="$TMP/bootstrap-checkout"
git clone --quiet --no-hardlinks "$ROOT" "$BOOTSTRAP_CHECKOUT"
if STARTER_KIT_REPO="$ROOT" \
  STARTER_KIT_DIR="$BOOTSTRAP_CHECKOUT" \
  STARTER_KIT_BRANCH=main \
  STARTER_KIT_COMMIT=0000000000000000000000000000000000000000 \
  bash -s -- --list < "$ROOT/install.sh" >/dev/null 2>&1
then
  fail "bootstrap accepted a ref that did not match its pinned commit"
fi
STARTER_KIT_REPO="$ROOT" \
STARTER_KIT_DIR="$BOOTSTRAP_CHECKOUT" \
STARTER_KIT_BRANCH=main \
STARTER_KIT_COMMIT="$PINNED_COMMIT" \
  bash -s -- --list < "$ROOT/install.sh" >/dev/null
printf 'local change\n' > "$BOOTSTRAP_CHECKOUT/untracked-change"
if STARTER_KIT_REPO="$ROOT" \
  STARTER_KIT_DIR="$BOOTSTRAP_CHECKOUT" \
  STARTER_KIT_BRANCH=main \
  STARTER_KIT_COMMIT="$PINNED_COMMIT" \
  bash -s -- --list < "$ROOT/install.sh" >/dev/null 2>&1
then
  fail "bootstrap executed from a dirty existing checkout"
fi
printf 'ok   bootstrap fails closed on commit and checkout drift\n'

# Given an ephemeral checkout and --dry-run, when the child exits, then cleanup
# remains operational even though user-facing install mutations are suppressed.
DRY_RUN_CHECKOUT="$TMP/dry-run-checkout"
git clone --quiet --no-hardlinks "$ROOT" "$DRY_RUN_CHECKOUT"
cp "$ROOT/install.sh" "$DRY_RUN_CHECKOUT/install.sh"
STARTER_KIT_DIR="$DRY_RUN_CHECKOUT" \
STARTER_KIT_EPHEMERAL_ROOT="$DRY_RUN_CHECKOUT" \
  bash "$DRY_RUN_CHECKOUT/install.sh" --dry-run --list >/dev/null
[[ ! -e "$DRY_RUN_CHECKOUT" ]] \
  || fail "dry-run bootstrap left its ephemeral checkout behind"
printf 'ok   dry-run bootstrap removes its ephemeral checkout\n'

# Given a normal AppKit launch, when the window installs its content hierarchy,
# then the stack must be constrained to a persistent root view. Making the
# stack itself the content view creates self-referential constraints and a
# blank window until a test-only forced layout happens.
macos_source="$(<"$ROOT/gui/macos/main.swift")"
brand_source="$(<"$ROOT/gui/macos/Brand.swift")"
session_source="$(<"$ROOT/gui/macos/InstallerProcessSession.swift")"
[[ "$session_source" == *"guard !self.finished else { return }"* ]] \
  || fail "macOS cancellation escalation can signal a completed process group"
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
[[ "$macos_source" != *"raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/install.sh"* ]] \
  || fail "macOS GUI still downloads a mutable main bootstrap"
[[ "$macos_source" == *"@objc private func dryRunDidChange()"* ]] \
  || fail "macOS GUI does not synchronize its primary action with preview state"
[[ "$macos_source" == *"private let cancelButton"* ]] \
  || fail "macOS GUI does not expose an in-app installation cancel action"
[[ "$macos_source" == *"func applicationShouldTerminate("* ]] \
  || fail "macOS GUI does not cancel active work before application termination"
[[ "$macos_source" != *"readDataToEndOfFile()"* ]] \
  || fail "macOS GUI can block forever waiting for inherited output pipes"
[[ "$macos_source" != *"let details: String"* ]] \
  || fail "macOS GUI profile copy is duplicated instead of deriving from selected steps"
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
release_version="$(<"$ROOT/VERSION")"
STARTER_KIT_RELEASE_REF="v$release_version" \
  STARTER_KIT_DEVELOPER_MODE=1 \
  bash "$ROOT/gui/macos/build-app.sh" "$DIST"
APP="$DIST/Lazy Starter Kit Installer.app"
[[ -x "$APP/Contents/MacOS/LazyStarterKitInstaller" ]] \
  || fail "macOS GUI app executable was not built"
app_arches="$(lipo -archs "$APP/Contents/MacOS/LazyStarterKitInstaller")"
[[ "$app_arches" == *"arm64"* && "$app_arches" == *"x86_64"* ]] \
  || fail "macOS GUI app is not universal: $app_arches"
[[ -f "$APP/Contents/Resources/AppIcon.icns" ]] \
  || fail "macOS GUI bundle does not contain its application icon"
[[ -f "$APP/Contents/Resources/install.sh" ]] \
  || fail "macOS GUI bundle does not contain its immutable installer bootstrap"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist")" == "AppIcon" ]] \
  || fail "macOS GUI bundle does not declare its application icon"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMultipleInstancesProhibited' "$APP/Contents/Info.plist" 2>/dev/null)" == "true" ]] \
  || fail "macOS GUI bundle permits duplicate application instances"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$release_version" ]] \
  || fail "macOS GUI bundle does not expose the release version"
deployment_target="$(
  xcrun vtool -show-build "$APP/Contents/MacOS/LazyStarterKitInstaller" \
    | awk '$1 == "minos" { print $2 }'
)"
[[ "$(printf '%s\n' "$deployment_target" | sort -u)" == "14.0" ]] \
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
[[ "$self_test" == *'"interfaceVersion":4'* ]] \
  || fail "macOS GUI self-test did not expose the redesigned interface version"
[[ "$self_test" == *'"supportsAppearanceSnapshots":true'* ]] \
  || fail "macOS GUI self-test did not expose light and dark appearance QA"
[[ "$self_test" == *"\"appVersion\":\"$release_version\""* ]] \
  || fail "macOS GUI self-test did not expose the release version"
[[ "$self_test" == *"\"releaseRef\":\"v$release_version\""* ]] \
  || fail "macOS GUI self-test did not pin its release ref"
[[ "$self_test" == *'"installerSource":"bundled"'* ]] \
  || fail "macOS GUI self-test did not expose its bundled bootstrap"
[[ "$self_test" == *'"actionTitlesTrackPreviewState":true'* ]] \
  || fail "macOS GUI self-test did not expose preview/install title synchronization"
[[ "$self_test" == *'"supportsCancellation":true'* ]] \
  || fail "macOS GUI self-test did not expose active-install cancellation"
[[ "$self_test" == *'"developerMode":true'* ]] \
  || fail "macOS GUI test build did not expose its explicit developer mode"
printf '%s' "$self_test" | grep -Eq '"releaseCommit":"[0-9a-f]{40}"' \
  || fail "macOS GUI self-test did not pin an immutable release commit"

# Given a normal optimized app launch, when AppKit finishes launching, then the
# controller must still be retained long enough to create the real window.
WINDOW_READY="$TMP/gui-window-ready.txt"
open -W -n \
  --env "STARTER_KIT_GUI_WINDOW_READY=$WINDOW_READY" \
  "$APP"
[[ "$(<"$WINDOW_READY")" == "window-ready" ]] \
  || fail "macOS GUI optimized app launch did not create its window"
printf 'ok   macOS GUI retains its controller through real app launch\n'
[[ "$self_test" == *'"releasesURL":"https:\/\/github.com\/Heoooooon\/lazy-starter-kit\/releases\/latest"'* ]] \
  || fail "macOS GUI self-test did not expose update guidance"
MIN_SNAPSHOT="$TMP/minimum-window.png"
"$APP/Contents/MacOS/LazyStarterKitInstaller" --snapshot-size "$MIN_SNAPSHOT" 700 723
[[ "$(sips -g pixelWidth "$MIN_SNAPSHOT" | awk '/pixelWidth/ {print $2}')" == "700" ]] \
  || fail "macOS GUI minimum-width snapshot was not rendered"
[[ "$(sips -g pixelHeight "$MIN_SNAPSHOT" | awk '/pixelHeight/ {print $2}')" == "723" ]] \
  || fail "macOS GUI minimum-height snapshot was not rendered"
printf 'ok   macOS GUI app builds and reports its contract\n'

# Given a harmless local payload, when the real GUI auto-starts for E2E QA,
# then the window/controller/download/process path completes successfully.
GUI_RESULT="$TMP/gui-result.txt"
GUI_LOG_RESULT="$TMP/gui-log-result.txt"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_INSTALL_SHA256="$PAYLOAD_SHA256" \
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

# Given a payload whose declared digest is wrong, when the GUI prepares it,
# then execution must stop before any payload code runs.
REJECT_RESULT="$TMP/gui-reject-result.txt"
REJECT_MARKER="$TMP/gui-reject-payload-ran"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_INSTALL_SHA256="$(printf tampered | shasum -a 256 | awk '{print $1}')" \
STARTER_KIT_PAYLOAD_MARKER="$REJECT_MARKER" \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_RESULT="$REJECT_RESULT" \
  "$APP/Contents/MacOS/LazyStarterKitInstaller"
IFS= read -r reject_status < "$REJECT_RESULT"
[[ "$reject_status" == "1" ]] \
  || fail "macOS GUI did not reject a payload with a mismatched digest"
[[ "$(sed -n '3p' "$REJECT_RESULT")" == "retry" ]] \
  || fail "macOS GUI digest refusal did not expose a retry action"
[[ ! -e "$REJECT_MARKER" ]] \
  || fail "macOS GUI executed a payload before verifying its digest"
printf 'ok   macOS GUI rejects installer payload integrity mismatches\n'

# Given cancellation before posix_spawn publishes a PID, when start is then
# dispatched, the session must finish cancelled without executing payload code.
PRESTART_RESULT="$TMP/gui-prestart-cancel-result.txt"
PRESTART_MARKER="$TMP/gui-prestart-payload-ran"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_INSTALL_SHA256="$PAYLOAD_SHA256" \
STARTER_KIT_PAYLOAD_MARKER="$PRESTART_MARKER" \
STARTER_KIT_GUI_CANCEL_BEFORE_START=1 \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_RESULT="$PRESTART_RESULT" \
  "$APP/Contents/MacOS/LazyStarterKitInstaller"
IFS= read -r prestart_status < "$PRESTART_RESULT"
[[ "$prestart_status" == "130" && "$(sed -n '3p' "$PRESTART_RESULT")" == "cancelled" ]] \
  || fail "macOS GUI pre-start cancellation did not report cancellation"
[[ ! -e "$PRESTART_MARKER" ]] \
  || fail "macOS GUI executed payload code after pre-start cancellation"
printf 'ok   macOS GUI cancels safely before process start\n'

# Given Quit while payload preparation is active, when AppKit asks to terminate,
# then it must defer exit, cancel preparation, emit completion, and run no code.
QUIT_RESULT="$TMP/gui-quit-result.txt"
QUIT_MARKER="$TMP/gui-quit-payload-ran"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_INSTALL_SHA256="$PAYLOAD_SHA256" \
STARTER_KIT_PAYLOAD_MARKER="$QUIT_MARKER" \
STARTER_KIT_GUI_QUIT_BEFORE_START=1 \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_RESULT="$QUIT_RESULT" \
  /usr/bin/perl -e 'alarm 20; exec @ARGV' \
  "$APP/Contents/MacOS/LazyStarterKitInstaller" --appearance light
IFS= read -r quit_status < "$QUIT_RESULT"
[[ "$quit_status" == "130" && "$(sed -n '3p' "$QUIT_RESULT")" == "cancelled" ]] \
  || fail "macOS GUI Quit did not wait for preparation cancellation"
[[ ! -e "$QUIT_MARKER" ]] \
  || fail "macOS GUI Quit allowed hidden payload execution"
printf 'ok   macOS GUI defers Quit until preparation is cancelled\n'

# Given the minimal preset, when the GUI starts a preview, then only that
# preset's component steps are passed to the installer.
MINIMAL_RESULT="$TMP/gui-minimal-result.txt"
MINIMAL_LOG_RESULT="$TMP/gui-minimal-log-result.txt"
STARTER_KIT_INSTALL_URL="file://$TMP/payload.sh" \
STARTER_KIT_INSTALL_SHA256="$PAYLOAD_SHA256" \
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
STARTER_KIT_INSTALL_SHA256="$PAYLOAD_SHA256" \
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
STARTER_KIT_INSTALL_SHA256="$PAYLOAD_SHA256" \
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
STARTER_KIT_INSTALL_SHA256="$PAYLOAD_SHA256" \
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

# Given an installer process tree that announces it is ready, when the GUI
# cancel path is triggered by that exact output event, then every process exits,
# the temporary payload is removed, and completion reports cancellation.
CANCEL_FIFO="$TMP/gui-cancel.fifo"
mkfifo "$CANCEL_FIFO"
# shellcheck disable=SC2016
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'trap '\''exit 0'\'' TERM' \
  'printf "%s\n" "$$" > "$STARTER_KIT_PARENT_PID"' \
  '(' \
  '  trap '\'''\'' TERM' \
  '  while :; do read -r _ < "$STARTER_KIT_CANCEL_FIFO"; done' \
  ') &' \
  'child=$!' \
  'printf "%s\n" "$child" > "$STARTER_KIT_CHILD_PID"' \
  'printf "QA_READY_FOR_CANCEL\n"' \
  'wait "$child"' > "$TMP/cancel-payload.sh"
CANCEL_SHA256="$(shasum -a 256 "$TMP/cancel-payload.sh" | awk '{print $1}')"
CANCEL_RESULT="$TMP/gui-cancel-result.txt"
CANCEL_LOG_RESULT="$TMP/gui-cancel-log.txt"
CANCEL_PARENT_PID="$TMP/gui-cancel-parent.pid"
CANCEL_CHILD_PID="$TMP/gui-cancel-child.pid"
STARTER_KIT_INSTALL_URL="file://$TMP/cancel-payload.sh" \
STARTER_KIT_INSTALL_SHA256="$CANCEL_SHA256" \
STARTER_KIT_CANCEL_FIFO="$CANCEL_FIFO" \
STARTER_KIT_PARENT_PID="$CANCEL_PARENT_PID" \
STARTER_KIT_CHILD_PID="$CANCEL_CHILD_PID" \
STARTER_KIT_GUI_CANCEL_ON_OUTPUT=QA_READY_FOR_CANCEL \
STARTER_KIT_GUI_AUTOSTART=1 \
STARTER_KIT_GUI_EXIT_ON_FINISH=1 \
STARTER_KIT_GUI_RESULT="$CANCEL_RESULT" \
STARTER_KIT_GUI_LOG_RESULT="$CANCEL_LOG_RESULT" \
  /usr/bin/perl -e '$SIG{ALRM}=sub{die "GUI cancel timeout\n"}; alarm 20; exec @ARGV' \
  "$APP/Contents/MacOS/LazyStarterKitInstaller" --appearance dark
IFS= read -r cancel_status < "$CANCEL_RESULT"
[[ "$cancel_status" == "130" ]] \
  || fail "macOS GUI cancellation did not report status 130"
[[ "$(sed -n '3p' "$CANCEL_RESULT")" == "cancelled" ]] \
  || fail "macOS GUI cancellation did not expose the cancelled action"
cancel_parent_pid="$(<"$CANCEL_PARENT_PID")"
cancel_child_pid="$(<"$CANCEL_CHILD_PID")"
if kill -0 "$cancel_parent_pid" 2>/dev/null; then
  fail "macOS GUI cancellation left the installer process running"
fi
if kill -0 "$cancel_child_pid" 2>/dev/null; then
  fail "macOS GUI cancellation left a child process running"
fi
grep -qxF "QA_READY_FOR_CANCEL" "$CANCEL_LOG_RESULT" \
  || fail "macOS GUI cancellation lost the event that triggered it"
printf 'ok   macOS GUI cancels and cleans up the active process tree\n'

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
