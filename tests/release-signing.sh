#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="$(<"$ROOT/.github/workflows/release.yml")"

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

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

printf 'PASS release signing contract\n'
