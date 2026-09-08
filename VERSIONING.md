# Versioning & stability policy

This project follows [Semantic Versioning](https://semver.org/). This document
defines **what counts as the public interface**, what you can script
against and pin, and what a version number promises about it.

## Release guidance: v0.14.0

**v0.14.0** adds the public `ai` profile and makes it the default for ordinary
no-profile installs and both GUIs. It also separates GUI Install and Preview
and adds executable-readiness and manual first-run guidance. Changing the
default payload and doctor semantics is a **pre-1.0 breaking change**, shipped
as a minor release under the policy below, not a patch.

v0.13.0 introduced `recommended`, first-use guidance, agent retirements, and the
no-uninstall policy. Its CLI default was full; its GUIs used recommended + preview.
Those explicit developer profiles and retirement policies remain in v0.14.0.
Older v0.12.0 archives retain the older agent roster, full GUI default and
automatic uninstall. Use v0.14.0 rather than reusing those ZIPs.

The standard remote bootstrap selects the newest release tag by default.
Packaged GUIs pin their own release commit, so downloading an old ZIP again won't
pick up untagged changes. A local source checkout runs its own files. Use the
[recommended setup guide](README.en.md#recommended-setup) to download the GUI
or clone `v0.14.0` and preview the local installer before applying. Record the
checkout commit when pinning source. Don't use an older
release if avoiding retired-agent installation is required.

## The public interface (semver-covered)

From v1.0.0, breaking any of these requires a **major** version bump. Before
v1.0.0, breaking changes use a minor bump and a changelog entry:

| Surface | Examples |
|---|---|
| **CLI flags** | `--only`, `--skip`, `--dry-run`, `--yes`, `--profile`, `--doctor`, `--update`, `--list`, `--version` (Windows: the `-PascalCase` equivalents); macOS-only `--doctor-json` for AI readiness |
| **Step ids** | install steps (`prereqs`, `brew`/`packages`, `runtimes`, `shell`, `docker`, `git`, `agents`, `wsl`); the values accepted by `--only`/`--skip` |
| **Profile names and defaults** | `ai` (ordinary no-profile install and GUI default since v0.14.0), `recommended` (since v0.13.0), `full`, `minimal`, `work`; custom step selections retain the developer payloads |
| **Managed-block markers** | `# >>> lazy-starter-kit:<tag> >>>` … `# <<< lazy-starter-kit:<tag> <<<` in `${ZDOTDIR-$HOME}/.zshrc`, `${ZDOTDIR-$HOME}/.zprofile`, PowerShell profiles; tools and users may key on these |
| **Environment variables** | `STARTER_KIT_BRANCH` (bootstrap ref; unset selects the newest release tag), `STARTER_KIT_COMMIT` (macOS/Windows bootstrap only: require the ref to resolve to one full 40-character commit SHA), `HERMES=1` (macOS/Linux advanced agent opt-in; ignored by `ai`), `ZDOTDIR` (non-empty absolute Zsh config directory), `ASSUME_YES`/CI non-interactive behavior |
| **Installer and doctor exit codes** | `0` success / `1` failure. AI doctor requires successful command execution; macOS also requires its safety configuration. Full inventory exits `1` for missing items; PATH-only warnings don't fail. Scope is defined below. |
| **macOS AI JSON diagnostics** | `--profile ai --doctor-json` emits `version`, `generatedAt`, `summary` (`ok`, `pathOnly`, `missing`) and `items` with `id`, `label`, `category`, `state`, `detail`, `step`; human-readable values aren't stable prose |
| **Backup behavior** | the one-time `.bak` backup before the first managed edit of a config file |

Non-breaking **minor** versions may add tools, steps, flags or profiles, change
log wording, and change *which versions* of tools get installed. A default
profile or diagnostic-scope change follows the breaking-change policy above.
**Patch** versions fix bugs without interface changes.

Linux doesn't enforce `STARTER_KIT_COMMIT`. To pin Linux installation code,
manually check out a reviewed full commit SHA in a local clone, confirm it with
`git rev-parse HEAD`, and run that checkout's `linux/install.sh` without
`--update`. Setting the variable on the Linux bootstrap isn't a commit pin.

## Profile and retirement policy (v0.14.0)

- `ai` prepares Git, Node LTS/npm, Claude Code, Codex, safety hooks, minimal
  persistent PATH and required prerequisites. It excludes Python, Go, Rust,
  Docker, Windows WSL, Bun, uv, shell cosmetics, fonts and the optional CLI
  bundle. macOS uses Homebrew `node@24`, Linux mise `node@lts`, and Windows
  winget `OpenJS.NodeJS.LTS`.
- `recommended` selects `prereqs`, `brew` (macOS) or `packages` (Linux/Windows),
  `runtimes`, `shell`, `git` and `agents`. Docker and Windows WSL are excluded.
- Ordinary CLI installs without a profile or custom step selection use `ai`.
  Both GUIs default to `ai`, with Install as the primary action and Preview
  separate. Explicit `full` still selects all steps. Selecting a Windows Docker/WSL step
  doesn't bypass its existing prompts, prerequisites or non-interactive limits.
- `minimal` excludes agents, Docker and Windows WSL. `work` selects the same
  steps as `recommended`; neither profile bypasses organization policy.
- Profiles add their exclusions to `--skip` / `-Skip` and can't be combined
  with `--only` / `-Only`. Selecting runtimes doesn't select Docker packages.
  Custom `--only` / `-Only` and unprofiled `--skip` / `-Skip` retain the wider
  developer-step payloads. `recommended` isn't an alias for `ai`.
- The agents step supports Claude Code and Codex. Retired gajae-code (`gjc`)
  and lazycodex aren't installed or deleted, and their existing configuration
  is preserved. Hermes needs `HERMES=1` and a non-AI selection that includes
  agents on macOS/Linux, for example `HERMES=1 ./install.sh --profile recommended`
  (Linux: `./linux/install.sh`). `ai` intentionally ignores inherited `HERMES=1`.
  There's no native Windows Hermes installer.
- Automatic uninstall is retired. The old entrypoints stop with a nonzero exit and
  perform no deletion; uninstall flags and groups are no longer supported.
  This pre-1.0 breaking change is recorded under v0.13.0 in the changelog.

## Diagnostic scope (v0.14.0)

- **macOS:** bare `--doctor` infers a recognized profile from
  `~/.local/share/lazy-starter-kit/install-profile`; without one, it checks the
  full inventory. Explicit `--profile ai --doctor` checks Git, Node, npm, Claude
  Code and Codex through a fresh login shell, plus the AI safety configuration.
  Use `--profile ai --doctor-json` for JSON with the same scope and exit status.
  JSON is supported only for AI scope, not the developer inventory.
- **Linux:** bare `--doctor` defaults to AI executable checks, as does
  `--profile ai --doctor`. It doesn't expose the macOS JSON flag.
- **Windows:** bare `-Doctor` remains the full inventory. AI scope requires
  explicit `-Profile ai -Doctor`; it checks the required AI executables.
  There is no Windows equivalent of `--doctor-json`.

Explicit developer profiles on every OS retain the full inventory. Unlike AI
readiness, that inventory can report a found but off-PATH tool without failing.
It can report intentionally omitted Docker/Colima as missing and exit 1; don't
install those tools just to make the report green. v0.13.0 used the full inventory
for every doctor run.

Successful installation or preview isn't proof of readiness. Check in a new
terminal. Login, account access, credits, and prompt submission aren't verified
by doctor or GUI readiness; the user completes the provider flow manually.

## Not covered (may change in any release)

- Upstream tool versions and availability. Default-profile selection and
  diagnostic scope are covered above; their changes aren't patch-only details.
- Install locations chosen by upstreams (`~/.local/bin`, brew prefix, …).
- Human-readable output formatting (colors, wording, ordering).
- The `docs/` assets and README structure.

## Pre-1.0 caveat

Until `v1.0.0`, minor versions (`0.x` → `0.y`) may include breaking changes;
we keep them rare and always list them in the [CHANGELOG](./CHANGELOG.md).
From `v1.0.0` on, the table above is a hard promise.

## Support tiers

| Tier | Platforms | Promise |
|---|---|---|
| **Tier 1** | macOS 14+ (Apple Silicon) · Windows Server 2025 (≈ Windows 11) · Ubuntu 24.04 · Fedora (latest) · Arch (latest) · openSUSE Tumbleweed | Install and verify jobs in CI, with platform-specific Docker/WSL exclusions; macOS/Ubuntu idempotency checks, Linux upgrade-path checks, and profile/agent regressions. No automatic uninstall jobs. |
| **Tier 2** | Windows 10 1809+ / 11 desktop · Debian 12+ · RHEL 9 / Rocky / Alma · openSUSE Leap · WSL2 (Ubuntu) · Intel Macs | Expected to work (same code paths), not automatically tested; regressions fixed with priority when reported |
| **Unsupported** | Alpine / musl distros · 32-bit systems | Upstream tools (node, ast-grep, bun) don't ship builds |

A weekly scheduled CI run re-tests Tier 1 against moving upstreams; failures
automatically open a [`ci-drift`](https://github.com/Heoooooon/lazy-starter-kit/issues?q=label%3Aci-drift) issue.

CI coverage isn't a claim that every native GUI or account flow was verified.
Portable PowerShell checks aren't native Windows WinForms/DPI E2E, and local
readiness checks don't verify provider authentication. Report native execution
and any unverified platform behavior separately.
