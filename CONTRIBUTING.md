# Contributing

Thanks for your interest! This kit has a deliberately tight scope. Reading this
first saves everyone time. Issues and PRs are welcome in Korean or English.

## Repo layout

```
.               macOS kit (install.sh, uninstall.sh, scripts/, Brewfile)
lib/common.sh   helpers shared by the macOS and Linux kits (sourced by both)
linux/          Linux kit (mirrors the macOS tree)
windows/        Windows kit (PowerShell 5.1 + 7)
.github/        CI: lint, platform install checks and regressions, release automation
```

## Scope: default AI, developer profiles, and optional extras

**Where a tool goes is the first question for any addition.** Since v0.14.0,
ordinary no-profile installs and both GUIs default to `ai`, not the full
developer bundle:

- **Default AI:** Git, Node LTS/npm, Claude Code, Codex, safety hooks, minimal
  persistent PATH and required prerequisites. No Python, Go, Rust, containers,
  Windows WSL, Bun, uv, shell cosmetics, fonts or optional CLI bundle. The goal
  is a small, working local AI setup, followed by manual login and a first prompt.
- **Explicit developer profiles:** `recommended`, `full`, `minimal`, and `work`
  retain their existing broader payloads. `recommended` isn't an alias for `ai`;
  it includes developer runtimes, CLI tools and shell customization without
  Docker or Windows WSL. `full` adds those steps with existing consent rules.
  The macOS [`Brewfile`](./Brewfile) describes developer tooling, not the default
  AI payload. Hermes is only an advanced macOS/Linux agent opt-in; `ai` ignores
  even an inherited `HERMES=1`.
- **Optional extras:** daily-use apps, niche tools and personal preferences
  belong in [`Brewfile.optional`](./Brewfile.optional), installed deliberately
  with `brew bundle --file Brewfile.optional`. They aren't beginner requirements.

Rule of thumb:

| Is it... | Goes in |
|---|---|
| Required to run Git, Node/npm, Claude Code or Codex safely | **Default AI**, only if needed on that OS |
| Broader development tooling, runtimes, shell customization or containers | **Explicit developer profiles** |
| A nice-to-have / GUI / daily-use / opinionated pick | **Optional** |

PRs must name the affected profiles and preserve the narrow `ai` payload.
Non-core additions belong in `Brewfile.optional`, not the default install.

## Ground rules for changes

- **bash 3.2 compatible**: macOS ships bash 3.2; no associative arrays,
  `mapfile`, `${x,,}`, etc. (`bash -n` must pass under `/bin/bash`).
- **Idempotent & non-destructive**: re-running must be safe; never clobber a
  user's existing config (fill empty values, use the managed-block markers).
- **shellcheck clean**: `shellcheck -x -S warning -e SC2154 install.sh uninstall.sh lib/common.sh scripts/*.sh`.
- **Shared helpers live in `lib/common.sh`**: the OS-agnostic bash helpers
  (colors, `run`, `ask`/`confirm`, `inject_block`, …) are shared by the macOS
  (`scripts/lib.sh`) and Linux (`linux/scripts/lib.sh`) kits, which source it and
  add only their OS-specific bits. Fix shared behavior in `lib/common.sh` so it
  can't land in only one tree.
- **The macOS and Linux bash trees stay diff-parallel**: if you change one
  `install.sh`/step script, make the same change in the sibling tree; only
  OS-specific bits (brew vs package managers, tool lists) may differ.
- **Windows PowerShell 5.1 compatible**: no `??`, no ternary, no `&&`/`||`
  pipeline chains; `Set-StrictMode -Version Latest` must pass, and native
  commands that write stderr are wrapped (`Invoke-NativeSilently`) because
  scripts run with `$ErrorActionPreference = 'Stop'`.
- **Preview first**: verify the default with `./install.sh --profile ai --dry-run`
  and preview any explicit developer profiles your change affects.
  Automatic uninstall is retired; legacy entrypoints stop without deletion.
- **CI must pass**: lint, macOS dry-run, and real installation/verification jobs.
- **Versioning**: user-visible changes bump [`VERSION`](./VERSION) and get a
  note in [`CHANGELOG.md`](./CHANGELOG.md). The flags, step ids, managed-block
  markers, profile defaults, diagnostic semantics and env vars are a **semver contract**; see
  [VERSIONING.md](./VERSIONING.md) before renaming anything.

## Before you open a PR

Run what CI runs:

```sh
# bash kits: lint
bash -n install.sh linux/install.sh lib/common.sh
shellcheck -x -S warning -e SC2154 install.sh uninstall.sh lib/common.sh \
  scripts/*.sh scripts/ai/lazy-safe-rm linux/install.sh linux/uninstall.sh linux/scripts/*.sh
node --check scripts/ai/shell-command-guard.js
node --check scripts/ai/install-shell-guard.js
tests/macos-existing-home.sh
tests/zdotdir-existing-home.sh
tests/safe-recursive-delete.sh
tests/ai-shell-guard.sh

# bash kits: behavior (no changes made)
./install.sh --dry-run && bash linux/install.sh --dry-run

# windows kit: parse check (works on macOS/Linux via Docker)
docker run --rm -v "$PWD":/src -w /src mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command 'Get-ChildItem windows -Recurse -Include *.ps1 |
    ForEach-Object { $t=$null;$e=$null;
      [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e)|Out-Null;
      if($e.Count){Write-Host "FAIL $($_.Name)"; exit 1} else {Write-Host "ok   $($_.Name)"} }'

# optional: a real end-to-end run in a throwaway container
docker run --rm -v "$PWD":/src ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq curl git ca-certificates >/dev/null &&
   cp -r /src /kit && cd /kit && bash linux/install.sh --yes --skip docker'
```

CI runs installation, verification, and doctor on macOS, Ubuntu, Fedora, Arch,
and openSUSE Tumbleweed. macOS and Ubuntu also repeat the real installation to
check idempotency, and Linux has an upgrade-path test. Windows runs regressions,
one real installation, and inline tool/profile verification; that job doesn't
run `-Doctor` or repeat the real installation. CI doesn't run automatic uninstall.
The checks above are enough to make a PR worth opening; the matrix catches the rest.

For onboarding changes, include the affected beginner-onboarding regressions
and distinguish fixture/portable results from native execution. Portable
PowerShell checks don't verify native WinForms/DPI, Windows console/registry
PATH notification or provider authentication. GUI readiness only checks local
tools; login and prompt submission stay manual. Pure prose changes need no
prose-pinning tests.

## Releases (maintainers)

Bump `VERSION`, move the `CHANGELOG.md` `[Unreleased]` section into a dated
release section, and update pinned-version examples in the READMEs and public
landing page. Use a PR and required CI for protected `main`; after merge and
verification, tag the release commit as `vX.Y.Z` and push the tag. The release
workflow publishes the GitHub Release automatically. The v0.14.0 default and
diagnostic changes use the pre-1.0 minor/breaking policy in [VERSIONING.md](VERSIONING.md).
Keep the existing four ZIP asset names when updating release links.

## Proposing an addition

Open an issue describing the tool, its **default AI**, **developer profile** or
**optional extra** scope,
and its license (prefer free/open-source). Small, well-scoped PRs welcome.
