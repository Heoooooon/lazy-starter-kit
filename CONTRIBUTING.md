# Contributing

Thanks for your interest! This kit has a deliberately tight scope. Reading this
first saves everyone time. Issues and PRs are welcome — in Korean or English.

## Repo layout

```
.               macOS kit (install.sh, uninstall.sh, scripts/, Brewfile)
lib/common.sh   helpers shared by the macOS and Linux kits (sourced by both)
linux/          Linux kit (mirrors the macOS tree)
windows/        Windows kit (PowerShell 5.1 + 7)
.github/        CI: lint + full e2e on 6 environments, release automation
```

## Scope: base vs. optional

The kit is split into two tiers, and **where a tool goes is the first question
for any addition**:

- **Base** — the default install (`install.sh` + [`Brewfile`](./Brewfile) + the
  `scripts/` steps). This is the **current, frozen, lean set**: prereqs, core dev
  CLI, runtimes (mise/rustup), shell, containers, Git/GitHub, and the AI coding
  agents. The base stays focused on **"a fresh Mac → a working dev environment."**
  It should grow slowly and only for things nearly everyone setting up a dev Mac
  needs.

- **Optional** — opt-in extras in [`Brewfile.optional`](./Brewfile.optional),
  installed only on purpose (`brew bundle --file Brewfile.optional`). **New
  additions that aren't core dev tooling go here** — daily-use apps, niche tools,
  personal preferences. This keeps the base from drifting into a "recommended
  apps" dump.

Rule of thumb:

| Is it... | Goes in |
|---|---|
| A tool ~every dev Mac needs (compiler, runtime, shell, VCS, container, agent) | **Base** |
| A nice-to-have / GUI / daily-use / opinionated pick | **Optional** |

PRs that add non-core tools to the base will be asked to move them to
`Brewfile.optional`.

## Ground rules for changes

- **bash 3.2 compatible** — macOS ships bash 3.2; no associative arrays,
  `mapfile`, `${x,,}`, etc. (`bash -n` must pass under `/bin/bash`).
- **Idempotent & non-destructive** — re-running must be safe; never clobber a
  user's existing config (fill empty values, use the managed-block markers).
- **shellcheck clean** — `shellcheck -x -S warning -e SC2154 install.sh uninstall.sh lib/common.sh scripts/*.sh`.
- **Shared helpers live in `lib/common.sh`** — the OS-agnostic bash helpers
  (colors, `run`, `ask`/`confirm`, `inject_block`, …) are shared by the macOS
  (`scripts/lib.sh`) and Linux (`linux/scripts/lib.sh`) kits, which source it and
  add only their OS-specific bits. Fix shared behavior in `lib/common.sh` so it
  can't land in only one tree.
- **The macOS and Linux bash trees stay diff-parallel** — if you change one
  `install.sh`/step script, make the same change in the sibling tree; only
  OS-specific bits (brew vs package managers, tool lists) may differ.
- **Windows PowerShell 5.1 compatible** — no `??`, no ternary, no `&&`/`||`
  pipeline chains; `Set-StrictMode -Version Latest` must pass, and native
  commands that write stderr are wrapped (`Invoke-NativeSilently`) because
  scripts run with `$ErrorActionPreference = 'Stop'`.
- **Preview first** — verify with `./install.sh --dry-run` (and `--dry-run` for
  uninstall).
- **CI must pass** — lint + macOS dry-run + a real install→uninstall run.
- **Versioning** — user-visible changes bump [`VERSION`](./VERSION) and get a
  note in [`CHANGELOG.md`](./CHANGELOG.md). The flags, step ids, managed-block
  markers, and env vars are a **semver contract** — see
  [VERSIONING.md](./VERSIONING.md) before renaming anything.

## Before you open a PR

Run what CI runs:

```sh
# bash kits — lint
bash -n install.sh linux/install.sh lib/common.sh
shellcheck -x -S warning -e SC2154 install.sh uninstall.sh lib/common.sh \
  scripts/*.sh linux/install.sh linux/uninstall.sh linux/scripts/*.sh

# bash kits — behavior (no changes made)
./install.sh --dry-run && bash linux/install.sh --dry-run

# windows kit — parse check (works on macOS/Linux via Docker)
docker run --rm -v "$PWD":/src -w /src mcr.microsoft.com/powershell:latest \
  pwsh -NoProfile -Command 'Get-ChildItem windows -Recurse -Include *.ps1 |
    ForEach-Object { $t=$null;$e=$null;
      [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e)|Out-Null;
      if($e.Count){Write-Host "FAIL $($_.Name)"; exit 1} else {Write-Host "ok   $($_.Name)"} }'

# optional: a real end-to-end run in a throwaway container
docker run --rm -v "$PWD":/src ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq curl git ca-certificates >/dev/null &&
   cp -r /src /kit && cd /kit && HERMES=0 bash linux/install.sh --yes --skip docker'
```

CI then runs the full install → verify → idempotency → doctor → uninstall cycle
on macOS, Windows, Ubuntu, Fedora, Arch, and openSUSE Tumbleweed, plus an
upgrade-path test — the checks above are enough to make a PR worth opening;
the matrix catches the rest.

## Releases (maintainers)

Bump `VERSION`, move the `CHANGELOG.md` `[Unreleased]` section into a dated
release section, update the pinned-version examples in the READMEs, then tag
`vX.Y.Z` and push the tag — the release workflow publishes the GitHub Release
automatically.

## Proposing an addition

Open an issue describing the tool, why it belongs in **base** vs **optional**,
and its license (prefer free/open-source). Small, well-scoped PRs welcome.
