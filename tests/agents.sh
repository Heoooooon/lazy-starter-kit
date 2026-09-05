#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
NODE_BIN="$(command -v node)"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

TMP_BASE="$REPO_ROOT/.tmp-tests"
[[ ! -L "$TMP_BASE" ]] || fail 'fixture base must not be a symlink'
mkdir -p "$TMP_BASE"
[[ "$(cd "$TMP_BASE" && pwd -P)" == "$TMP_BASE" ]] || fail 'fixture base escapes worktree'
WORK="$(mktemp -d "$TMP_BASE/agents.XXXXXX")"
OWNER_TOKEN="agents:$$:$RANDOM:$RANDOM"
readonly REPO_ROOT TMP_BASE WORK OWNER_TOKEN
printf '%s\n' "$OWNER_TOKEN" > "$WORK/.agents-owner"

validate_fixture_root() {
  local candidate="$1"
  [[ "$candidate" == "$WORK" && "$candidate" == "$TMP_BASE"/agents.* \
    && "$TMP_BASE" == "$REPO_ROOT/.tmp-tests" \
    && ! -L "$TMP_BASE" && ! -L "$candidate" && -d "$candidate" \
    && ! -L "$candidate/.agents-owner" && -f "$candidate/.agents-owner" ]] || return 1
  [[ "$(cd "$candidate" && pwd -P)" == "$candidate" ]] || return 1
  printf '%s\n' "$OWNER_TOKEN" | cmp -s - "$candidate/.agents-owner"
}
cleanup() {
  local status=$?
  validate_fixture_root "$WORK" || {
    printf 'FAIL: refusing cleanup: fixture boundary or ownership changed: %s\n' "$WORK" >&2
    return 1
  }
  printf 'cleanup: safe_rm_rf_under "%s" "%s"\n' "$TMP_BASE" "$WORK"
  DRY_RUN=0 safe_rm_rf_under "$TMP_BASE" "$WORK" || return 1
  return "$status"
}
trap cleanup EXIT
validate_fixture_root "$WORK" || fail 'invalid fixture ownership'
for boundary in "$REPO_ROOT" "$TMP_BASE" "${HOME:-/}"; do
  if validate_fixture_root "$boundary"; then fail "accepted non-fixture boundary: $boundary"; fi
done
mkdir "$WORK/runner-home" "$WORK/tmp"
export HOME="$WORK/runner-home" USERPROFILE="$WORK/runner-home"
export TMPDIR="$WORK/tmp" TMP="$WORK/tmp" TEMP="$WORK/tmp"
unset BASH_ENV ENV
printf 'fixtures: root=%s HOME=%s USERPROFILE=%s TMPDIR=%s\n' "$WORK" "$HOME" "$USERPROFILE" "$TMPDIR"

run_case() (
  platform="$1" mode="$2"
  ROOT="$REPO_ROOT"
  [[ "$platform" != linux ]] || ROOT="$REPO_ROOT/linux"
  validate_fixture_root "$WORK" || fail 'invalid fixture boundary before agent step'
  export HOME="$WORK/$platform-$mode" USERPROFILE="$WORK/$platform-$mode"
  export TRACE="$WORK/$platform-$mode.trace"
  export PATH=/usr/bin:/bin DRY_RUN=0 ASSUME_YES=1 HERMES=0
  case "$mode" in dry|dry-no-npm|hermes-dry) DRY_RUN=1 ;; esac
  case "$mode" in hermes|hermes-installed|hermes-dry) HERMES=1 ;; esac
  mkdir "$HOME"
  printf 'fixture: %s/%s HOME=%s USERPROFILE=%s TMPDIR=%s\n' "$platform" "$mode" "$HOME" "$USERPROFILE" "$TMPDIR"
  : > "$TRACE"

  # Existing legacy binaries, configuration and data are never migration targets.
  sentinels=(
    .bun/bin/gjc .local/bin/lazycodex
    .gajae/config.json .config/gajae-code/config.json .gjc/session.json
    .lazycodex/config.json .codex/config.toml .codex/sessions/sentinel
    .codex/plugins/cache/sisyphuslabs/omo/sentinel
  )
  for file in "${sentinels[@]}"; do
    mkdir -p "$(dirname "$HOME/$file")"
    printf 'user-owned:%s\n' "$file" > "$HOME/$file"
  done
  chmod +x "$HOME/.bun/bin/gjc" "$HOME/.local/bin/lazycodex"
  mkdir -p "$HOME/.claude"
  printf '%s\n' '{"userSentinel":true,"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"user-owned-hook"}]}]}}' \
    > "$HOME/.claude/settings.json"
  cp "$HOME/.claude/settings.json" "$HOME/.codex/hooks.json"

  record() { printf '%s\n' "$*" >> "$TRACE"; }
  load_brew() { :; }
  load_local_bins() { export PATH="$HOME/.local/bin:$PATH"; }
  load_mise() { :; }
  have() {
    case "$1" in
      bun|node|mise) return 0 ;;
      npm) [[ "$mode" != no-npm && "$mode" != dry-no-npm ]] ;;
      claude|codex) [[ "$mode" == installed || "$mode" == hermes-installed ]] ;;
      hermes) [[ "$mode" == hermes-installed ]] ;;
      gjc|lazycodex) record "probe $1"; [[ "$mode" == installed ]] ;;
      *) return 1 ;;
    esac
  }
  # All package-manager and legacy calls are intercepted, including RED runs.
  bun() { record "bun $*"; }
  npx() { record "npx $*"; }
  gjc() { record "gjc $*"; }
  lazycodex() { record "lazycodex $*"; }
  npm() { record "npm $*"; }
  mise() { record "mise $*"; }
  claude() { record "claude $*"; printf 'fixture-claude\n'; }
  codex() { record "codex $*"; printf 'fixture-codex\n'; }
  hermes() { record "hermes $*"; printf 'fixture-hermes\n'; }
  node() {
    record "node $*"
    "$NODE_BIN" "$@"
  }
  curl() {
    [[ "$#" == 4 && "$1" == -fsSL && "$3" == -o ]] || return 91
    local agent
    case "$2" in
      https://claude.ai/install.sh) agent=claude ;;
      https://hermes-agent.nousresearch.com/install.sh) agent=hermes ;;
      *) record "unexpected download $2"; return 92 ;;
    esac
    record "download $agent"
    # Exercise the real download/shebang/bash path, without network or installs.
    printf '#!/usr/bin/env bash\nprintf "installer %s %%s\\n" "$*" >> "$TRACE"\n' "$agent" > "$4"
  }

  # shellcheck disable=SC1090
  source "$ROOT/scripts/07-agents.sh"
  step_agents > "$WORK/$platform-$mode.output" 2>&1

  if grep -E 'gjc|gajae-code|lazycodex|^npx |^bun ' "$TRACE"; then
    fail "$platform/$mode invoked a legacy agent"
  fi
  expected="$WORK/$platform-$mode.expected"
  : > "$expected"
  case "$mode" in
    installed|hermes-installed) printf '%s\n' 'claude --version' 'codex --version' >> "$expected" ;;
    fresh|hermes)
      printf '%s\n' 'download claude' 'installer claude ' 'npm install -g @openai/codex' 'mise reshim' >> "$expected" ;;
    no-npm) printf '%s\n' 'download claude' 'installer claude ' >> "$expected" ;;
  esac
  guard="$ROOT/scripts/ai/install-shell-guard.js"
  [[ "$platform" != linux ]] || guard="$ROOT/../scripts/ai/install-shell-guard.js"
  case "$mode" in
    no-npm|dry-no-npm) ;;
    *) printf 'node %s --home %s%s\n' "$guard" "$HOME" "$( [[ "$DRY_RUN" != 1 ]] || printf ' --dry-run' )" >> "$expected" ;;
  esac
  case "$mode" in
    hermes) printf '%s\n' 'download hermes' 'installer hermes --skip-setup' >> "$expected" ;;
    hermes-installed) printf '%s\n' 'hermes --version' >> "$expected" ;;
  esac
  diff -u "$expected" "$TRACE" || fail "$platform/$mode command trace changed"

  for file in "${sentinels[@]}"; do
    printf 'user-owned:%s\n' "$file" | cmp -s - "$HOME/$file" \
      || fail "$platform/$mode changed legacy sentinel $file"
  done
  [[ -x "$HOME/.bun/bin/gjc" && -x "$HOME/.local/bin/lazycodex" ]] \
    || fail "$platform/$mode changed legacy executable permissions"

  # Run the actual safety installer and inspect parsed hooks, not its prose.
  "$NODE_BIN" - "$HOME" "$mode" <<'JS'
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const [home, mode] = process.argv.slice(2);
const installsGuard = !['dry', 'dry-no-npm', 'no-npm', 'hermes-dry'].includes(mode);
for (const file of ['.codex/hooks.json', '.claude/settings.json']) {
  const config = JSON.parse(fs.readFileSync(path.join(home, file), 'utf8'));
  assert.strictEqual(config.userSentinel, true);
  const commands = config.hooks.PreToolUse.flatMap(group => group.hooks.map(hook => hook.command));
  assert(commands.includes('user-owned-hook'));
  assert.strictEqual(commands.filter(command => command.includes('shell-command-guard.js')).length, installsGuard ? 1 : 0);
}
assert.strictEqual(fs.existsSync(path.join(home, '.local/bin/lazy-safe-rm')), installsGuard);
JS
  printf 'ok: %s/%s\n' "$platform" "$mode"
)

doctor_case() (
  local platform="$1"
  ROOT="$REPO_ROOT"
  [[ "$platform" != linux ]] || ROOT="$REPO_ROOT/linux"
  validate_fixture_root "$WORK" || fail 'invalid fixture boundary before doctor'
  export HOME="$WORK/$platform-doctor" USERPROFILE="$WORK/$platform-doctor"
  export TRACE="$WORK/$platform-doctor.trace"
  mkdir "$HOME"
  printf 'fixture: %s/doctor HOME=%s USERPROFILE=%s TMPDIR=%s\n' "$platform" "$HOME" "$USERPROFILE" "$TMPDIR"
  : > "$TRACE"
  # Source the actual doctor function without executing bootstrap or preflight.
  # Its probes are controlled so only an obsolete requirement can fail health.
  source /dev/stdin <<< "$(awk '/^doctor\(\) \{/{copy=1} copy{print} copy && /^}/{exit}' "$ROOT/install.sh")"
  cache_zsh_config_dir() { :; }
  zsh_config_file() { printf '%s/%s\n' "$HOME" "$1"; }
  brew_prefix() { printf '/fixture/brew\n'; }
  load_mise() { :; }
  _doctor_config() { :; }
  _doctor_tool() {
    [[ "$2" != agents ]] || printf '%s\n' "$1" >> "$TRACE"
    case "$1" in gjc|lazycodex) _DOCTOR_MISSING=$((_DOCTOR_MISSING + 1)) ;; esac
  }
  _doctor_runtime() { :; }
  export KIT_VERSION=fixture
  local status=0
  (doctor) > "$WORK/$platform-doctor.output" 2>&1 || status=$?
  [[ "$status" == 0 ]] || fail "$platform doctor requires legacy tooling (exit $status)"
  printf 'codex\nclaude\n' | diff -u - "$TRACE" || fail "$platform doctor agent roster changed"
  printf 'ok: %s/doctor without legacy tools\n' "$platform"
)

failures=0
for platform in macos linux; do
  for mode in fresh installed dry dry-no-npm no-npm hermes hermes-installed hermes-dry; do
    # A separate bash keeps errexit active inside each fixture, even while the
    # parent collects failures to expose both platforms in a single RED run.
    export REPO_ROOT NODE_BIN WORK TMP_BASE OWNER_TOKEN
    export -f run_case fail validate_fixture_root
    bash -c 'set -euo pipefail; source "$REPO_ROOT/lib/common.sh"; run_case "$@"' _ "$platform" "$mode" \
      || failures=$((failures + 1))
  done
  doctor_case "$platform" || failures=$((failures + 1))
done
[[ "$failures" == 0 ]] || fail "$failures agent scenarios failed"
printf 'ok: agent installation and doctor contracts (18 scenarios)\n'
