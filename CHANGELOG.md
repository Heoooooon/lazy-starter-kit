# Changelog

All notable changes to **lazy-starter-kit** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- **Recursive deletion now fails closed on every platform.** macOS/Linux route
  all recursive removal through one Bash 3.2-compatible strict-descendant guard;
  Windows uses a literal-path guard that rejects roots and reparse points. The
  every Bash batch and each Windows target is validated before deletion,
  including dry-run and `--yes`.
- **Codex and Claude Code now block recursive `rm` before execution.** The agents
  step idempotently merges `PreToolUse` hooks into existing user settings, keeps
  one-time backups, covers direct and nested-shell forms, and installs
  `lazy-safe-rm` for cleanup confined to the current Git workspace. Hooks remain
  defense in depth; the sandbox is still the final containment boundary.
- **Existing macOS setups no longer stop before shell activation** when
  Homebrew sees a manually installed Orca app or another Brewfile entry fails.
  Existing formulae are not proactively upgraded (though Homebrew may still
  upgrade required dependencies), independent shell setup still runs, and a
  partial package failure is reported with exit code 1 at the end.
- **Existing custom oh-my-zsh plugin directories no longer hide the kit's
  autosuggestions and syntax-highlighting plugins** on macOS or Linux; the shell
  block falls back to the deterministic directory where the installer cloned
  them.
- **Existing `ZDOTDIR` layouts now receive active Zsh configuration** on macOS
  and Linux, including standard non-interactive values assigned in `.zshenv`.
  Install, doctor, guidance, and uninstall consistently target the active
  `.zshrc` and macOS `.zprofile`, while stale kit blocks from the old HOME path
  are removed. Empty or relative values are rejected because they cannot provide
  a stable per-user startup path.

## [0.8.0] - 2026-07-12

### Changed
- **macOS: the default terminal cask is now [Orca](https://github.com/stablyai/orca)
  (`stablyai/orca` tap), replacing cmux** — Orca is the MIT-licensed Agent
  Development Environment (parallel agents in isolated git worktrees,
  Ghostty-class terminal, restart-surviving scrollback, `orca` CLI on PATH,
  sha256-pinned cask with a `zap` stanza). cmux remains detected by the
  `shell` step, so existing installs keep their font seeding; swap back any
  time by editing the Brewfile (`cask "cmux"` / `cask "ghostty"`).

### Added
- **Antigravity CLI (`agy`, Google) as a strictly opt-in agent** — Gemini
  CLI's closed-source successor (small free tier), so it is never installed
  by default: pass `ANTIGRAVITY=1` to the installer (`$env:ANTIGRAVITY='1'`
  on Windows). Uses the same download-then-verify pattern as Claude Code;
  the uninstallers remove the binary. Not part of `--doctor` or CI (opt-in
  tools must not fail the health contract).
- **Modern-CLI pack in `Brewfile.optional`** (opt-in): eza, zoxide, atuin,
  git-delta, lazygit. The zsh block (macOS + Linux) gains guarded hooks —
  eza `ls`/`ll`/`lt` aliases, `zoxide init`, and `atuin init` placed after
  fzf so atuin owns Ctrl-R — all inert unless the tools are installed.

## [0.7.0] - 2026-07-05

### Changed
- **Windows: one `wsl` run now advances through every stage that doesn't need a
  reboot** (was: one stage per run). The step loops detect→act, so once WSL is
  usable a single interactive run registers Ubuntu, initializes it as root, and
  offers the Linux kit — no more re-running between registration and init. A
  required reboot still stops the pipeline (it never reboots for you); re-run
  after rebooting to resume. Validated end-to-end on the real test machine,
  including recovery after an interrupted in-distro install.

### Fixed
- **Windows: mise's "chpwd requires PowerShell 7" warning on every new 5.1
  shell** — the kit's profile block now sets `MISE_PWSH_CHPWD_WARNING=0` on
  PowerShell < 7; the auto-version-switch-on-cd hook is a nice-to-have there,
  and the warning read as an error to beginners.

## [0.6.0] - 2026-07-05

### Changed
- **Windows: WSL step is out of beta** — the full pipeline (engine install →
  reboot → Ubuntu registration → root init → the Linux kit inside →
  idempotent re-run) was validated end-to-end on a real, factory-fresh
  Windows 11 25H2 machine (ko-KR, OneDrive-redirected Documents), including
  `--doctor` exit-0 inside Ubuntu.

### Fixed
- **Windows: `-Doctor` misreported mise runtimes as missing** — piping
  `Invoke-NativeSilently` output into `Select-Object -First 1` stopped the
  pipeline early, killing the still-running native process and leaving
  `$LASTEXITCODE` at `-1`; slow-starting `mise which` lost that race every
  time, so node/go/python showed as missing on healthy installs. The helper
  now buffers its output so the process always completes. Found on real
  hardware (fresh Windows 11, ko-KR).
- **Windows: the `irm | iex` one-liner died on fresh machines** — after
  bootstrapping (git install + clone), the hand-off executed the cloned
  `install.ps1` as a *file*, which the factory-default execution policy
  (`Restricted`) blocks with `PSSecurityException` — the iex'd *string* was
  exempt, the file was not. The iex path now hands off in a child process
  with a process-scoped `-ExecutionPolicy Bypass` (GPO still wins).
  Found reproducing a user report on a brand-new Windows 11 PC.

### Added
- **Stability contract** — [VERSIONING.md](./VERSIONING.md) defines the
  semver-covered public interface (flags, step/group ids, profiles,
  managed-block markers, env vars, exit codes) and the Tier 1/2 support
  matrix; READMEs gained the matrix, CONTRIBUTING gained multi-OS ground
  rules + the exact pre-PR check commands.
- **CI: `--doctor` exit-code contract** — after every e2e install (Ubuntu,
  the distro matrix, macOS), CI now runs `--doctor` and requires exit 0.

## [0.5.0] - 2026-07-04

### Added
- **`--profile` / `-Profile` presets** — `minimal` (toolchain only: CLI +
  runtimes + shell + git), `work` (corporate PCs: everything except Docker —
  and WSL on Windows — with the heavy Hermes agent off), `full` (default).
  Combines with `--skip` (union) and refuses `--only` (contradictory).
- **CI: upgrade-path test** — installs from the newest release tag, then
  re-runs the current kit on top and verifies tools + zero duplicated
  managed blocks, so upgrades are proven, not assumed.
- **CI: silent-failure alert** — the weekly drift-detection cron now opens
  (or bumps) a `ci-drift` issue when it fails instead of failing silently.

### Fixed
- **Linux uninstall leftovers**: removing gh now also drops GitHub's apt
  repo + keyring; removing Docker drops Docker's package repo (apt/dnf/
  zypper); the shell group points out how to `chsh` back if zsh was made
  the login shell.

- **Windows: WSL2 automation (`wsl` step, beta — not yet exercised on real hardware)** — detects the current WSL state and
  advances one stage per run (never reboots for you): enables WSL2 + Ubuntu
  behind a Docker-Desktop-style default-No gate (admin required; big
  reboot-and-re-run guidance when Windows needs it), initializes Ubuntu
  non-interactively as root, then offers to run the **Linux kit inside** — so
  claude/codex/mise/starship and Hermes (no native Windows build) all land in
  Ubuntu. `-Only wsl` to run it explicitly; uninstall offers `wsl --unregister
  Ubuntu` behind a default-No data-loss prompt (never under `-Yes`).

## [0.4.0] - 2026-07-03

### Added
- **`--doctor` / `-Doctor`** — read-only health report on all three kits:
  every kit tool as ok / installed-but-off-PATH (with the "open a new
  terminal" hint) / missing (with the exact `--only <step>` fix), plus
  managed-block and starship config checks. Exit 1 only on real misses.
- **`--update` / `-Update`** — pulls the latest kit (`git pull --ff-only`)
  and re-runs the updated installer with your remaining flags.
- **CI: idempotency is now a test** — the Ubuntu and macOS e2e jobs run the
  full install a second time and assert zero duplicated managed blocks.

## [0.3.1] - 2026-07-03

### Added
- After a successful **interactive** install, the kit asks (default **No**)
  whether to star the repo on GitHub via the just-authenticated `gh` session.
  Never shown — and nothing is ever starred — under `--yes`/`-Yes`,
  non-interactive runs, or CI, and it skips users who already starred.

## [0.3.0] - 2026-07-03

### Added
- **Claude Code (`claude`) installs by default on all three kits** via the
  official native installer (`claude.ai/install.sh` / `install.ps1`) into
  `~/.local/bin`, with the kit's temp-file download verification. The agent
  keeps itself updated. Uninstall removes the binary and (confirm-gated,
  with a `.claude.json` backup) the `~/.claude` settings/history. CI verifies
  install and removal on all six environments.

### Fixed
- CI: mise's GitHub API version lookups are authenticated with the job token
  (anonymous requests share the runner IP's 60/hr limit and flaked).

## [0.2.0] - 2026-07-02

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
- **CI distro matrix**: Fedora, Arch and openSUSE Tumbleweed now run the full
  install→verify→uninstall e2e in containers on every change (previously
  Ubuntu-only in CI).
- **Release automation**: pushing a `v*` tag creates a GitHub Release with
  auto-generated notes.
- **Repo hygiene**: `SECURITY.md` (reporting + supply-chain scope), GitHub issue
  forms (bug/feature), PR template, and Dependabot for GitHub Actions.

### Security
- GitHub Actions are pinned to full commit SHAs (checkout bumped to v7 / Node 24).
- The oh-my-zsh bootstrap installer is pinned to a reviewed commit instead of
  `master`; the get.docker.com script is downloaded to a temp file and sanity-
  checked instead of being piped straight into a root shell.
- README now states the supply-chain tradeoff plainly (upstream installers over
  HTTPS, npm/bun packages at latest) and links SECURITY.md.

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
- **Config safety (all OSes)**: managed-block editing now refuses to touch a file
  with an unmatched `>>>`/`<<<` marker (previously everything below a lone marker
  could be deleted) and makes a one-time `<file>.lazy-starter-kit.bak` backup
  before the first edit of an existing file.
- **Windows / PowerShell 5.1**: native commands with `2>$null` no longer kill the
  installer under `$ErrorActionPreference='Stop'` (e.g. `gh auth status` when not
  logged in); profile edits preserve the file's original encoding/BOM (Korean
  comments survive); `irm … | iex` no longer closes the terminal on exit; the
  profile block is written to (and removed from) **both** the 5.1 and PS 7
  profiles; session PATH updates merge instead of replacing.
- **Linux**: a box without usable sudo now skips system packages with one clear
  warning and still installs the user-space tools (previously the whole run
  aborted); `pacman -Syu` is confirm-gated instead of upgrading the system
  unprompted; the gh apt-repo setup and `$USER` expansion can no longer abort
  the install; `pm_install` lazily refreshes the package index so
  `--only packages` works on a fresh machine.
- **Non-interactive honesty**: `--yes`/`-Yes` no longer launches the interactive
  `gh auth login` / lazycodex wizards, and no longer auto-installs Docker Desktop
  on Windows (licensing); dry-run output now previews steps it previously skipped
  silently and no longer claims "backed up" without copying.
- **Uninstall**: codex is detected/removed with plain `npm -g` (previously missed
  unless mise managed node); Windows winget uninstalls no longer report "removed"
  when they failed.
- **CLI polish**: unknown `--only`/`--skip` (`-Only`/`-Skip`) step ids now fail
  loudly instead of silently doing nothing; `--help` no longer leaks code lines;
  `-V/--version` documented; the macOS Xcode CLT wait is bounded (~30 min) instead
  of spinning forever; `cat`→`bat` now actually works on Windows (alias precedence).

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

[Unreleased]: https://github.com/Heoooooon/lazy-starter-kit/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/Heoooooon/lazy-starter-kit/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Heoooooon/lazy-starter-kit/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/Heoooooon/lazy-starter-kit/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Heoooooon/lazy-starter-kit/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Heoooooon/lazy-starter-kit/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Heoooooon/lazy-starter-kit/releases/tag/v0.1.0
