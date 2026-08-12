#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="$(<"$ROOT/.github/workflows/release.yml")"

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

# Release and CI entrypoints are invoked directly, so their executable mode is
# part of the shipped contract rather than a local convenience.
for executable in \
  Install-lazy-starter-kit.command \
  install.sh \
  gui/macos/build-app.sh \
  tests/install-entrypoints.sh \
  tests/release-signing.sh; do
  [[ -x "$ROOT/$executable" ]] \
    || fail "$executable is not executable"
done

# Given a tagged release, when the macOS installer job runs, then it must use
# the real Developer ID + Apple notarization secrets rather than ad-hoc signing.
for token in \
  'MACOS_CERTIFICATE_P12_BASE64' \
  'MACOS_CERTIFICATE_PASSWORD' \
  'ASC_API_KEY_P8_BASE64' \
  'ASC_API_KEY_ID' \
  'ASC_API_ISSUER_ID' \
  'Developer ID Application: CMORE (XC844652SJ)' \
  '--options runtime' \
  'notarytool submit' \
  'stapler staple' \
  'spctl --assess'; do
  [[ "$WORKFLOW" == *"$token"* ]] || fail "release workflow is missing: $token"
done
[[ "$WORKFLOW" != *'codesign --force --deep --sign -'* ]] \
  || fail "release workflow still uses ad-hoc signing"

# Windows PowerShell 5.1 decodes BOM-less UTF-8 as the active ANSI code page.
# The release job must therefore read the Korean launchers explicitly as UTF-8,
# package the shared safe-delete helper, verify digest substitution, and write
# portable LF checksum sidecars.
for token in \
  '[System.IO.File]::ReadAllText' \
  '[System.Text.Encoding]::UTF8' \
  'windows-gui\cleanup-lib.ps1' \
  'windows-gui\cleanup-installer-clone.ps1' \
  "UTF8Encoding(\$true)" \
  'macOS launcher digest placeholder was not replaced' \
  'Windows GUI digest placeholder was not replaced' \
  'Windows launcher digest placeholder was not replaced' \
  'lazy-starter-kit-windows-gui.zip`n' \
  'lazy-starter-kit-windows-double-click.zip`n'; do
  [[ "$WORKFLOW" == *"$token"* ]] || fail "release packaging is missing: $token"
done
[[ "$WORKFLOW" != *'Get-Content gui\windows\installer.ps1 -Raw'* ]] \
  || fail 'release workflow decodes the Windows GUI with the default code page'
[[ "$WORKFLOW" != *'Get-Content windows\Install-lazy-starter-kit.cmd -Raw'* ]] \
  || fail 'release workflow decodes the Windows launcher with the default code page'

printf 'PASS release signing and packaging contract\n'
