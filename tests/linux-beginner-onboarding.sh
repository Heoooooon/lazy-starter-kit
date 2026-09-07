#!/usr/bin/env bash
# Linux CLI integration: real step scripts and safety installer, fake downloads
# and package managers. Run in Linux with Node available; no network is used.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(uname -s)" == Linux ]] || { echo 'Run this test on Linux (e.g. node:22-slim).' >&2; exit 1; }
REAL_NODE="$(command -v node)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/linux-onboarding.XXXXXX")"
printf 'fixtures: %s\n' "$TMP"
mkdir -p "$TMP/kit/linux" "$TMP/kit/lib" "$TMP/kit/scripts" "$TMP/bin" "$TMP/system-bin"
# Expose only test infrastructure, never a preinstalled Git/Node/npm/agent.
for utility in bash sh env uname dirname basename head sed tr awk mktemp cat rm grep cut tail mkdir cp chmod id true find ln cmp; do
  ln -s "$(command -v "$utility")" "$TMP/system-bin/$utility"
done
cp "$ROOT/linux/install.sh" "$ROOT/linux/uninstall.sh" "$TMP/kit/linux/"
cp -R "$ROOT/linux/scripts" "$ROOT/linux/config" "$TMP/kit/linux/"
cp "$ROOT/lib/common.sh" "$TMP/kit/lib/"
cp -R "$ROOT/scripts/ai" "$TMP/kit/scripts/"
cp "$ROOT/VERSION" "$TMP/kit/"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
has() { grep -qF -- "$2" "$1" || fail "$1 missing: $2"; }
lacks() { if grep -qE -- "$2" "$1"; then fail "$1 unexpectedly matches: $2"; fi; }

cat > "$TMP/bin/tool" <<'EOF'
#!/bin/bash
set -eu
tool="${0##*/}"
printf '%s %s\n' "$tool" "$*" >> "$TRACE"
if [[ "${1:-}" == --version ]]; then
  [[ "${FAIL_TOOL:-}" != "$tool" ]] || exit 17
  echo "$tool fixture 1.0"
  exit 0
fi
case "$tool" in
  node) exec "$REAL_NODE" "$@" ;;
  npm)
    prefix="$HOME/npm-global"
    action=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --prefix) prefix="$2"; shift ;;
        install) action="$1" ;;
      esac
      shift
    done
    package="$prefix/lib/node_modules/@openai/codex"
    case "$action" in
      install)
        if [[ "${MISSING_TOOL:-}" != codex ]]; then
          mkdir -p "$prefix/bin" "$package/bin"
          printf '{"name":"@openai/codex","version":"1.0.0"}\n' > "$package/package.json"
          cp "$FIXTURE_BIN/tool" "$package/bin/codex"
          ln -sf ../lib/node_modules/@openai/codex/bin/codex "$prefix/bin/codex"
        fi ;;
      *) exit 19 ;;
    esac
    ;;
  mise)
    case "$*" in
      'use -g node@lts')
        mkdir -p "$HOME/.local/share/mise/shims"
        for name in node npm; do
          [[ "${MISSING_TOOL:-}" == "$name" ]] || cp "$FIXTURE_BIN/tool" "$HOME/.local/share/mise/shims/$name"
        done ;;
      'activate bash --shims') echo ':' ;;
      reshim) : ;;
      *) exit 20 ;;
    esac ;;
  git) [[ "${1:-}" == config ]] || exit 21 ;;
  *) exit 22 ;;
esac
EOF
cat > "$TMP/bin/curl" <<'EOF'
#!/bin/bash
set -eu
printf 'curl %s\n' "$*" >> "$TRACE"
case "$*" in
  *https://mise.run*)
    printf '%s\n' '#!/bin/sh' 'mkdir -p "$HOME/.local/bin"' 'cp "$FIXTURE_BIN/tool" "$HOME/.local/bin/mise"' ;;
  *https://claude.ai/install.sh*)
    [[ "${3:-}" == -o ]] || exit 23
    printf '%s\n' '#!/bin/bash' 'mkdir -p "$HOME/.local/bin"' '[[ "${MISSING_TOOL:-}" == claude ]] || cp "$FIXTURE_BIN/tool" "$HOME/.local/bin/claude"' > "$4" ;;
  *) exit 24 ;;
esac
EOF
cat > "$TMP/bin/apt-get" <<'EOF'
#!/bin/bash
set -eu
printf 'apt-get %s\n' "$*" >> "$TRACE"
if [[ "$*" == *install* ]]; then
  mkdir -p "$HOME/.local/bin"
  [[ "${MISSING_TOOL:-}" == git ]] || cp "$FIXTURE_BIN/tool" "$HOME/.local/bin/git"
fi
EOF
# Authentication and optional tool execution must never happen on the AI path.
cat > "$TMP/bin/gh" <<'EOF'
#!/bin/bash
printf 'gh %s\n' "$*" >> "$TRACE"
exit 29
EOF
cat > "$TMP/bin/sudo" <<'EOF'
#!/bin/bash
[[ "${1:-}" != -n ]] || shift
exec "$@"
EOF
chmod +x "$TMP/bin/"*

run_case() {
  local name="$1"; shift
  CASE_HOME="$TMP/$name 한글 home"
  mkdir -p "$CASE_HOME"
  TRACE_FILE="$TMP/$name.trace"
  OUTPUT="$TMP/$name.log"
  : > "$TRACE_FILE"
  STATUS=0
  env -i HOME="$CASE_HOME" LANG=C.UTF-8 SHELL="${TEST_SHELL:-/bin/bash}" PATH="$TMP/bin:$TMP/system-bin" \
    ZDOTDIR="${TEST_ZDOTDIR:-$CASE_HOME}" XDG_CONFIG_HOME="${TEST_XDG_CONFIG_HOME:-$CASE_HOME/.config}" \
    TRACE="$TRACE_FILE" FIXTURE_BIN="$TMP/bin" REAL_NODE="$REAL_NODE" \
    FAIL_TOOL="${FAIL_TOOL:-}" MISSING_TOOL="${MISSING_TOOL:-}" HERMES="${HERMES:-0}" \
    /bin/bash "$TMP/kit/linux/install.sh" "$@" > "$OUTPUT" 2>&1 || STATUS=$?
}

# Explicit AI and ordinary no-profile installs must both take the narrow path.
for name in explicit default; do
  args=(--yes)
  [[ "$name" != explicit ]] || args+=(--profile ai)
  run_case "$name" "${args[@]}"
  [[ "$STATUS" == 0 ]] || { /bin/cat "$OUTPUT"; fail "$name exit $STATUS"; }
  has "$TRACE_FILE" 'mise use -g node@lts'
  has "$TRACE_FILE" '@openai/codex'
  lacks "$TRACE_FILE" 'python|go@|rust|docker|bun|astral|starship|zoxide|ohmyzsh|gh |hermes|build-essential|zsh|ripgrep|ast-grep'
  for tool in git node npm claude codex; do has "$TRACE_FILE" "$tool --version"; done
  [[ -x "$CASE_HOME/.local/bin/lazy-safe-rm" ]] || fail 'safety executable missing'
  [[ ! -e "$CASE_HOME/.local/share/lazy-starter-kit/codex-local-prefix" ]] || fail 'uninstall lifecycle receipt created'
  "$REAL_NODE" - "$CASE_HOME" <<'EOF'
const fs = require('fs');
for (const file of ['.claude/settings.json', '.codex/hooks.json']) {
  const config = JSON.parse(fs.readFileSync(`${process.argv[2]}/${file}`, 'utf8'));
  if (!config.hooks.PreToolUse.some(group => group.hooks.some(h => h.command.includes('shell-command-guard.js')))) process.exit(1);
}
EOF
  # A fresh interactive Bash with no inherited installer PATH must find all tools.
  env -i HOME="$CASE_HOME" PATH="$TMP/system-bin" TRACE="$TRACE_FILE" REAL_NODE="$REAL_NODE" \
    /bin/bash --noprofile -ic 'for tool in git node npm claude codex; do "$tool" --version || exit; done' \
    > "$TMP/$name.new-terminal.log" 2>&1 || fail 'new terminal PATH'
  printf 'ok AI %s install, real safety hooks, fresh terminal\n' "$name"
done

# Automatic removal is retired. Every mode must leave tools, hooks and user
# settings byte-identical, with no npm/package-manager commands.
home="$CASE_HOME"
for mode in default preview agents shell; do
  args=()
  case "$mode" in
    preview) args=(--dry-run) ;;
    agents) args=(--yes --only agents) ;;
    shell) args=(--yes --only shell) ;;
  esac
  "$REAL_NODE" - "$home" > "$TMP/before-uninstall.json" <<'EOF'
const fs = require('fs');
const path = require('path');
function snapshot(root) {
  return fs.readdirSync(root).sort().map(name => {
    const file = path.join(root, name), stat = fs.lstatSync(file);
    return [name, stat.mode, stat.isSymbolicLink() ? fs.readlinkSync(file) :
      stat.isDirectory() ? snapshot(file) : fs.readFileSync(file).toString('base64')];
  });
}
console.log(JSON.stringify(snapshot(process.argv[2])));
EOF
  : > "$TRACE_FILE"
  status=0
  env -i HOME="$home" PATH="$TMP/bin:$TMP/system-bin" TRACE="$TRACE_FILE" \
    /bin/bash "$TMP/kit/linux/uninstall.sh" "${args[@]}" > "$TMP/retired-$mode.log" 2>&1 || status=$?
  [[ "$status" == 2 && ! -s "$TRACE_FILE" ]] || fail "retired uninstall $mode executed actions or exit $status"
  "$REAL_NODE" - "$home" "$TMP/before-uninstall.json" <<'EOF'
const fs = require('fs');
const path = require('path');
function snapshot(root) {
  return fs.readdirSync(root).sort().map(name => {
    const file = path.join(root, name), stat = fs.lstatSync(file);
    return [name, stat.mode, stat.isSymbolicLink() ? fs.readlinkSync(file) :
      stat.isDirectory() ? snapshot(file) : fs.readFileSync(file).toString('base64')];
  });
}
if (JSON.stringify(snapshot(process.argv[2])) !== fs.readFileSync(process.argv[3], 'utf8').trim()) process.exit(1);
EOF
done
printf 'ok retired uninstall leaves all installed tools, settings and safety hooks intact\n'

# Preview must leave even an empty HOME empty and execute no installer commands.
run_case preview --yes --dry-run --profile ai
[[ "$STATUS" == 0 && -z "$(find "$CASE_HOME" -mindepth 1 -print -quit)" ]] || fail 'preview mutated HOME or failed'
[[ ! -s "$TRACE_FILE" ]] || fail 'preview ran an installer/tool'

# An opt-in inherited from a broader profile must not expand the AI payload.
HERMES=1 run_case ai-no-extras --yes --profile ai
[[ "$STATUS" == 0 ]] || fail 'AI with inherited optional-agent setting failed'
lacks "$TRACE_FILE" 'hermes|python|bun|docker|gh '

# A populated preview must not execute the installed agents or safety installer.
run_case explicit --yes --dry-run --profile ai
[[ "$STATUS" == 0 && ! -s "$TRACE_FILE" ]] || fail 'populated preview executed commands'

# Missing and non-executable-success tools are both action-needed, not success.
for tool in git node npm claude codex; do
  FAIL_TOOL="$tool" run_case "fail-$tool" --yes --profile ai
  [[ "$STATUS" != 0 ]] || fail "broken $tool reported success"
  MISSING_TOOL="$tool" run_case "missing-$tool" --yes --profile ai
  [[ "$STATUS" != 0 ]] || fail "missing $tool reported success"
done

# Corrupt user safety settings are preserved and block readiness.
mkdir -p "$TMP/guard-failure 한글 home/.claude"
printf '{invalid\n' > "$TMP/guard-failure 한글 home/.claude/settings.json"
run_case guard-failure --yes --profile ai
[[ "$STATUS" != 0 ]] || fail 'broken safety hook reported success'
[[ "$(< "$CASE_HOME/.claude/settings.json")" == '{invalid' ]] || fail 'user settings overwritten'

# Existing shell content survives; Bash profile precedence and idempotence work.
home="$TMP/existing 한글 home"
mkdir -p "$home"
printf 'export USER_SENTINEL=kept\n' > "$home/.bashrc"
printf 'export LOGIN_SENTINEL=kept\n' > "$home/.bash_profile"
for pass in 1 2; do
  run_case existing --yes --profile ai
  [[ "$STATUS" == 0 ]] || fail "existing HOME pass $pass"
done
env -i HOME="$home" PATH=/usr/bin:/bin /bin/bash --noprofile --norc -c \
  '. "$HOME/.bash_profile"; . "$HOME/.bashrc"; [[ "$USER_SENTINEL:$LOGIN_SENTINEL" == kept:kept ]]; command -v codex' \
  > "$TMP/existing.path.log" || fail 'existing shell config or login PATH lost'
[[ "$(grep -c '^# >>> lazy-starter-kit:ai-path >>>$' "$home/.bashrc")" == 1 ]] || fail 'duplicate PATH block'

mkdir -p "$TMP/damaged-path 한글 home"
printf '# >>> lazy-starter-kit:ai-path >>>\nexport KEEP_ME=1\n' > "$TMP/damaged-path 한글 home/.bashrc"
cp "$TMP/damaged-path 한글 home/.bashrc" "$TMP/damaged-path.before"
run_case damaged-path --yes --profile ai
[[ "$STATUS" != 0 ]] || fail 'damaged PATH config reported success'
cmp "$TMP/damaged-path.before" "$CASE_HOME/.bashrc" || fail 'damaged PATH config changed'

# Retain the reference's installation coverage for both Bash login precedence
# variants and user-selected Zsh/Fish config roots, without restoring removal.
for login_file in .bash_profile .bash_login; do
  name="config-$login_file's"
  home="$TMP/$name 한글 home"
  zdir="$home/설정 zsh"; xdg="$home/fish config"
  files=("$home/.profile" "$home/.bashrc" "$home/$login_file" "$zdir/.zshrc" "$xdg/fish/conf.d/lazy-starter-kit-ai.fish")
  for file in "${files[@]}"; do
    mkdir -p "$(dirname "$file")"
    printf '# USER_CONFIG_SENTINEL\n' > "$file"
  done
  for pass in 1 2; do
    TEST_ZDOTDIR="$zdir" TEST_XDG_CONFIG_HOME="$xdg" TEST_SHELL=/usr/bin/fish \
      run_case "$name" --yes --profile ai
    [[ "$STATUS" == 0 ]] || fail "$login_file config installation pass $pass"
  done
  for file in "${files[@]}"; do
    [[ "$(grep -cx '# USER_CONFIG_SENTINEL' "$file")" == 1 ]] || fail "user config changed: $file"
    [[ "$(grep -cx '# >>> lazy-starter-kit:ai-path >>>' "$file")" == 1 ]] || fail "missing/duplicate PATH block: $file"
  done
done

# Exercise actual native shells when present in the Linux validation image.
if real_zsh="$(command -v zsh)"; then
  ln -s "$real_zsh" "$TMP/system-bin/zsh"
  mkdir -p "$TMP/zsh 한글 home"
  printf 'export ZDOTDIR="$HOME/설정 zsh"\n' > "$TMP/zsh 한글 home/.zshenv"
  run_case zsh --yes --profile ai
  [[ "$STATUS" == 0 && -f "$CASE_HOME/설정 zsh/.zshrc" && ! -e "$CASE_HOME/.zshrc" ]] || fail 'ZDOTDIR not respected'
  env -i HOME="$CASE_HOME" PATH="$TMP/system-bin" TRACE="$TRACE_FILE" REAL_NODE="$REAL_NODE" \
    "$real_zsh" -ic 'for tool in git node npm claude codex; do "$tool" --version || exit; done' \
    > "$TMP/zsh.new-terminal.log" 2>&1 || fail 'new Zsh PATH'
  printf 'ok native Zsh new terminal with Korean/spaced ZDOTDIR\n'
else
  printf 'not exercised: native Zsh is unavailable\n'
fi
if real_fish="$(command -v fish)"; then
  TEST_SHELL="$real_fish" run_case fish --yes --profile ai
  [[ "$STATUS" == 0 ]] || fail 'fish PATH installation'
  # Fish imports HOME before its locale startup. Keep a real UTF-8 terminal
  # locale so its C-locale fallback cannot misdecode Korean path bytes.
  env -i HOME="$CASE_HOME" LANG=C.UTF-8 TERM=xterm PATH="$TMP/system-bin" TRACE="$TRACE_FILE" REAL_NODE="$REAL_NODE" \
    "$real_fish" -ic 'for tool in git node npm claude codex; $tool --version; or exit; end' \
    > "$TMP/fish.new-terminal.log" 2>&1 || fail 'new Fish PATH'
  printf 'ok native Fish new terminal\n'
else
  printf 'not exercised: native Fish is unavailable\n'
fi

# Legacy presets and explicit selection keep their step membership and toolchain.
for spec in recommended:prereqs,packages,runtimes,shell,git,agents full:prereqs,packages,runtimes,shell,docker,git,agents minimal:prereqs,packages,runtimes,shell,git work:prereqs,packages,runtimes,shell,git,agents; do
  profile="${spec%%:*}" expected="${spec#*:}"
  # Legacy Git setup requires an existing Git even during preview. Preserve
  # that upstream behavior rather than treating its early exit as a pass.
  mkdir -p "$TMP/$profile 한글 home/.local/bin"
  cp "$TMP/bin/tool" "$TMP/$profile 한글 home/.local/bin/git"
  run_case "$profile" --yes --dry-run --profile "$profile"
  # The step registry line is structured CLI data, not prose copy.
  actual="$(awk '/steps: /{sub(/^.*steps: /, ""); sub(/ *\(profile:.*/, ""); sub(/ *$/, ""); gsub(/ /, ","); print}' "$OUTPUT")"
  [[ "$STATUS" == 0 && "$actual" == "$expected" ]] || fail "$profile step selection: $actual (exit $STATUS)"
  has "$OUTPUT" python@latest
done
run_case skip-legacy --yes --dry-run --skip docker,git
has "$OUTPUT" 'python@latest'
mkdir -p "$TMP/only 한글 home/.local/bin"
cp "$TMP/bin/tool" "$TMP/only 한글 home/.local/bin/git"
run_case only --yes --only git
[[ "$STATUS" == 0 ]] || fail 'selective git required unselected tools'
lacks "$TRACE_FILE" 'node --version|npm --version|claude --version|codex --version'
run_case only-preview --yes --dry-run --only packages
[[ "$STATUS" == 0 ]] || fail 'selective packages falsely required unselected tools'
lacks "$TRACE_FILE" 'git --version|node --version|npm --version|claude --version|codex --version'
run_case conflict --yes --profile ai --only agents
[[ "$STATUS" != 0 ]] || fail 'profile/only conflict accepted'
run_case skip-ai --yes --profile ai --skip agents
[[ "$STATUS" == 0 ]] || fail 'AI skip checked unselected agents'
lacks "$TRACE_FILE" 'claude|codex'

# Default/AI doctor validates only its executable contract, including failures.
for option in default ai; do
  args=(--doctor)
  [[ "$option" != ai ]] || args+=(--profile ai)
  run_case existing "${args[@]}"
  [[ "$STATUS" == 0 ]] || fail "$option doctor rejected healthy recommended install"
  for tool in git node npm claude codex; do has "$TRACE_FILE" "$tool --version"; done
  lacks "$TRACE_FILE" 'python|rust|docker|bun|uv|starship'
done
FAIL_TOOL=codex run_case existing --profile ai --doctor
[[ "$STATUS" != 0 ]] || fail 'doctor accepted failing --version'
run_case full-doctor --profile full --doctor
[[ "$STATUS" != 0 ]] || fail 'full doctor accepted absent full toolchain'
# Reject malformed selectors before any step, including with doctor.
for selector in only skip profile; do
  for value in '' ' '; do
    run_case invalid --yes "--$selector=$value"
    [[ "$STATUS" != 0 && ! -s "$TRACE_FILE" ]] || fail "accepted empty $selector"
  done
  run_case invalid --yes "--$selector" --doctor
  [[ "$STATUS" != 0 && ! -s "$TRACE_FILE" ]] || fail "accepted missing $selector"
done
for selector in only skip; do
  for value in ',agents' 'agents,' 'shell,,agents' typo; do
    run_case invalid --yes "--$selector=$value" --doctor
    [[ "$STATUS" != 0 && ! -s "$TRACE_FILE" ]] || fail "accepted invalid $selector=$value"
  done
done
printf 'PASS Linux beginner onboarding\n'
