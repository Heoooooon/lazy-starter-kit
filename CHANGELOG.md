# Changelog

All notable changes to **lazy-starter-kit** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Linux kit** (`linux/`): the same 7-step, idempotent, dry-run-first installer
  for Linux. Auto-detects the package manager (apt · dnf/yum · pacman · zypper)
  for base/CLI tools and installs the developer toolchain (mise, starship,
  uv, bun, rustup) from official user-space installers — no Homebrew, no root for
  the per-user tools. Steps: `prereqs packages runtimes shell docker git agents`.
  Includes `uninstall.sh` and a dedicated README.
- **Windows kit** (`windows/`): a PowerShell installer (`install.ps1`, 5.1+/7+)
  using **winget** for packages plus **mise**/**rustup** for runtimes. Wires up a
  managed PowerShell profile block (starship, PSReadLine, PSFzf, bun/cargo PATH),
  Docker Desktop (opt-in), git identity, and the AI agents (gajae-code, codex,
  lazycodex; Hermes via WSL2). Includes `uninstall.ps1` and a README.
- **CI**: added `lint-linux` (shellcheck + `bash -n`) and `lint-windows`
  (PowerShell parse + PSScriptAnalyzer) jobs.
- **Docs**: root README now links all three platform kits (macOS at root,
  `linux/`, `windows/`).
- **Real end-to-end CI on all three OSes**: `windows-latest` (Server 2025) and
  `ubuntu-latest` install→verify→uninstall jobs, alongside the existing macOS one.
  Agents (gajae-code + codex) are covered on Linux and Windows.
- **Verified end-to-end on Ubuntu, Fedora, openSUSE and Arch** (glibc). Alpine/
  musl is explicitly **unsupported** (upstream node/ast-grep/bun have no musl builds).

### Changed
- **Windows**: winget installs prefer per-user (`--scope user`) and fall back to
  the default scope, so standard (non-admin) accounts install more; a summary
  lists any packages that still need admin. `-Only`/`-Skip` now accept comma
  lists (`-Only packages,shell`). PSReadLine is upgraded to 2.2+ for inline
  autosuggestions, plus CompletionPredictor + Tab menu + history search.
- **Linux**: Python uses mise's **precompiled** builds (`MISE_PYTHON_COMPILE=0`);
  `fd`/`bat` get real command symlinks on Debian/Ubuntu; oh-my-zsh plugin clones
  retry and are non-fatal; pacman refresh uses `-Syu` (avoids partial-upgrade
  breakage on Arch).

### Fixed
- **Rename** `macos-starter-kit` → `lazy-starter-kit` across code, URLs, managed-
  block tags, and clone dir; installs/uninstalls migrate legacy `macos-starter-kit:*`
  blocks so re-runs stay duplicate-free.
- `set -e` bug: `load_local_bins` aborted the Linux install when the mise shims
  dir did not exist yet.

## [0.1.0] - 2026-06-27

First public release. One command turns a fresh MacBook into a complete dev
environment, verified end-to-end (install → uninstall) on a clean macOS VM
and on every push via GitHub Actions.

### Added
- **Installer** (`install.sh`): 7 idempotent, dependency-ordered steps —
  `prereqs → brew → runtimes → shell → docker → git → agents`. Bootstraps via
  `curl … | bash` (self-clones, then re-execs). Flags: `--dry-run`, `--yes`,
  `--only`, `--skip`, `--no-agents`, `--list`, `--version`, `--help`.
- **prereqs**: Xcode Command Line Tools + Homebrew.
- **brew** (`Brewfile`): git, gh, jq, ripgrep, fd, fzf, bat, tree, wget,
  ast-grep, **mole**, starship, mise, uv, rustup, bun, colima, docker (+compose
  /buildx), JetBrainsMono Nerd Font, and the **cmux** terminal.
- **runtimes**: node (LTS), python, go via **mise**; rust + rust-analyzer via
  **rustup**. Warns when a non-mise runtime is already installed (shadowing).
- **shell**: oh-my-zsh + plugins `(git npm node macos)` + zsh-autosuggestions +
  zsh-syntax-highlighting, starship prompt, managed `~/.zshrc` block.
- **docker**: Colima + docker CLI plugin wiring (Docker Desktop not required).
- **git**: identity (GitHub noreply email), HTTPS credential helper, sane
  defaults — only fills empty values, never clobbers.
- **agents**: gajae-code (`gjc`), codex, lazycodex (OmO), and Hermes Agent
  (`hermes`, skippable with `HERMES=0`).
- **Uninstaller** (`uninstall.sh`): reverse-order teardown, confirm-gated,
  `--with-gajae` / `--keep-codex-home`. Never auto-removes Homebrew, Xcode CLT,
  or your git identity.
- **Docs**: English + Korean READMEs, GitHub Pages install-flow page,
  Permissions and "running on a Mac that already has tools" sections.
- **CI**: GitHub Actions — shellcheck/syntax, macOS dry-run, and a real
  install→uninstall integration job; weekly schedule to catch upstream drift.
- **Versioning**: `VERSION` file, `--version` flag, this changelog.

### Fixed
- `brew bundle`: dropped the removed `--no-lock` flag (use `brew bundle install`).
- agents: `mise reshim` after the global codex install so its shim is on PATH.
- uninstall: `brew autoremove` to sweep orphaned transitive deps (e.g. node@24).
- dry-run: `brew`/`runtimes` steps degrade gracefully on a bare machine instead
  of aborting when prerequisite tools aren't installed yet.

[Unreleased]: https://github.com/Heoooooon/lazy-starter-kit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Heoooooon/lazy-starter-kit/releases/tag/v0.1.0
