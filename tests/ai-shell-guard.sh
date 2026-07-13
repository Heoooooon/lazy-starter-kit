#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE="${NODE:-$(command -v node)}"
GUARD="$ROOT/scripts/ai/shell-command-guard.js"
source "$ROOT/lib/common.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
guard_status() {
  local command="$1"
  set +e
  "$NODE" -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",tool_input:{command:process.argv[1]}}))' "$command" \
    | "$NODE" "$GUARD" >/dev/null 2>&1
  local status=$?
  set -e
  printf '%s\n' "$status"
}
expect_block() { [[ "$(guard_status "$1")" == "2" ]] || fail "guard allowed: $1"; }
expect_allow() { [[ "$(guard_status "$1")" == "0" ]] || fail "guard blocked: $1"; }

expect_block 'rm -rf build'
expect_block 'rm -fr build'
expect_block 'rm -R build'
expect_block 'rm --force --recursive build'
expect_block '/bin/rm -rf build'
expect_block 'sudo /usr/bin/rm -rf build'
expect_block 'env FOO=1 rm -rf build'
expect_block 'find build -type f -print0 | xargs -0 rm -rf'
expect_block "sh -c 'rm -rf build'"
expect_block "r''m -rf build"
continued_rm="rm \\"$'\n'"-rf build"
expect_block "$continued_rm"
expect_allow 'rm -f file.txt'
expect_allow 'lazy-safe-rm build'
expect_allow 'printf safe'

set +e
printf 'not-json' | "$NODE" "$GUARD" >/dev/null 2>&1
bad_status=$?
set -e
[[ "$bad_status" == "2" ]] || fail 'malformed hook input did not fail closed'

TMP_BASE="${TMPDIR:-/tmp}"; TMP_BASE="${TMP_BASE%/}"
TMP_ROOT="$(mktemp -d "$TMP_BASE/lsk-ai-guard.XXXXXX")"
trap 'safe_rm_rf_under "$TMP_BASE" "$TMP_ROOT" >/dev/null 2>&1 || true' EXIT
home="$TMP_ROOT/home"
mkdir -p "$home/.codex" "$home/.claude"
printf '%s\n' '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"printf existing"}]}]},"existing":true}' > "$home/.codex/hooks.json"
printf '%s\n' '{"permissions":{"allow":["Read"]},"existing":true}' > "$home/.claude/settings.json"

"$NODE" "$ROOT/scripts/ai/install-shell-guard.js" --home "$home" >/dev/null
"$NODE" "$ROOT/scripts/ai/install-shell-guard.js" --home "$home" >/dev/null
"$NODE" - "$home" <<'NODE'
const fs = require('fs');
const path = require('path');
const home = process.argv[2];
for (const file of [path.join(home, '.codex/hooks.json'), path.join(home, '.claude/settings.json')]) {
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (data.existing !== true) throw new Error(`existing settings lost in ${file}`);
  const handlers = (data.hooks.PreToolUse || []).flatMap((group) => group.hooks || []);
  const managed = handlers.filter((handler) => String(handler.command || '').includes('shell-command-guard.js'));
  if (managed.length !== 1) throw new Error(`expected one managed hook in ${file}, got ${managed.length}`);
  if (!fs.existsSync(`${file}.bak`)) throw new Error(`missing one-time backup for ${file}`);
}
NODE

workspace="$TMP_ROOT/workspace"
outside="$TMP_ROOT/outside"
mkdir -p "$workspace/build" "$outside"
printf 'keep\n' > "$outside/sentinel"
git -C "$workspace" init -q
(cd "$workspace" && HOME="$home" "$home/.local/bin/lazy-safe-rm" "$workspace/build")
[[ ! -e "$workspace/build" && -f "$outside/sentinel" ]] || fail 'lazy-safe-rm crossed the workspace boundary'
expect_cli_reject=0
(cd "$workspace" && HOME="$home" "$home/.local/bin/lazy-safe-rm" "$workspace" >/dev/null 2>&1) || expect_cli_reject=1
[[ "$expect_cli_reject" == "1" && -d "$workspace" ]] || fail 'lazy-safe-rm accepted the workspace root'
ln -s "$outside" "$workspace/link"
(cd "$workspace" && HOME="$home" "$home/.local/bin/lazy-safe-rm" "$workspace/link" >/dev/null 2>&1) && fail 'lazy-safe-rm accepted a symlink target'
[[ -f "$outside/sentinel" ]] || fail 'lazy-safe-rm symlink test removed outside data'

"$NODE" "$ROOT/scripts/ai/install-shell-guard.js" uninstall --home "$home" >/dev/null
[[ ! -e "$home/.local/bin/lazy-safe-rm" ]] || fail 'AI safety uninstaller left lazy-safe-rm behind'
"$NODE" - "$home" <<'NODE'
const fs = require('fs');
const path = require('path');
const home = process.argv[2];
for (const file of [path.join(home, '.codex/hooks.json'), path.join(home, '.claude/settings.json')]) {
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (data.existing !== true) throw new Error(`existing settings lost in ${file}`);
  const text = JSON.stringify(data);
  if (text.includes('shell-command-guard.js')) throw new Error(`managed hook remained in ${file}`);
}
NODE

printf 'ok: Codex and Claude block recursive rm and retain a guarded workspace alternative\n'
