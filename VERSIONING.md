# Versioning & stability policy

This project follows [Semantic Versioning](https://semver.org/). This document
defines **what counts as the public interface**, what you can script
against and pin, and what a version number promises about it.

## Current source versus published releases

The latest published release remains **v0.12.0**. It uses the older agent
roster, defaults to the full profile, and includes automatic uninstall. The
recommended profile and retirement policies below are unreleased source changes
from [PR #6](https://github.com/Heoooooon/lazy-starter-kit/pull/6),
[PR #21](https://github.com/Heoooooon/lazy-starter-kit/pull/21) and
[PR #22](https://github.com/Heoooooon/lazy-starter-kit/pull/22). `VERSION` remains
`0.12.0`; a local `--version` / `-Version` result alone doesn't identify these
changes. Record the checkout commit when pinning source.

The standard remote bootstrap selects the newest release tag by default.
Packaged GUIs pin their own release commit, so downloading v0.12.0 again won't
pick up untagged changes. A local source checkout runs its own files. Use the
[recommended setup guide](README.en.md#recommended-setup) to explicitly clone
`main` and preview the local installer before applying. Don't use an older
release if avoiding retired-agent installation is required.

## The public interface (semver-covered)

Breaking any of these requires a **major** version bump:

| Surface | Examples |
|---|---|
| **CLI flags** | `--only`, `--skip`, `--dry-run`, `--yes`, `--profile`, `--doctor`, `--update`, `--list`, `--version` (Windows: the `-PascalCase` equivalents) |
| **Step ids** | install steps (`prereqs`, `brew`/`packages`, `runtimes`, `shell`, `docker`, `git`, `agents`, `wsl`); the values accepted by `--only`/`--skip` |
| **Profile names** | `recommended` (current source), `full`, `minimal`, `work` |
| **Managed-block markers** | `# >>> lazy-starter-kit:<tag> >>>` … `# <<< lazy-starter-kit:<tag> <<<` in `${ZDOTDIR-$HOME}/.zshrc`, `${ZDOTDIR-$HOME}/.zprofile`, PowerShell profiles; tools and users may key on these |
| **Environment variables** | `STARTER_KIT_BRANCH` (bootstrap ref; unset selects the newest release tag), `STARTER_KIT_COMMIT` (macOS/Windows bootstrap only: require the ref to resolve to one full 40-character commit SHA), `HERMES=1` (opt in to the Hermes agent, macOS/Linux), `ZDOTDIR` (non-empty absolute Zsh config directory), `ASSUME_YES`/CI non-interactive behavior |
| **Installer exit codes** | `0` success / `1` failure; `--doctor` / `-Doctor` exits `0` when nothing in its full inventory is missing (PATH-only warnings don't fail) and `1` when something is missing |
| **Backup behavior** | the one-time `.bak` backup before the first managed edit of a config file |

**Minor** versions may: add tools to the default set, add steps/flags/profiles,
change log wording, change *which versions* of tools get installed.
**Patch** versions fix bugs without interface changes.

Linux doesn't enforce `STARTER_KIT_COMMIT`. To pin Linux installation code,
manually check out a reviewed full commit SHA in a local clone, confirm it with
`git rev-parse HEAD`, and run that checkout's `linux/install.sh` without
`--update`. Setting the variable on the Linux bootstrap isn't a commit pin.

## Profile and retirement policy (current source)

- `recommended` selects `prereqs`, `brew` (macOS) or `packages` (Linux/Windows),
  `runtimes`, `shell`, `git` and `agents`. Docker and Windows WSL are excluded.
- The CLI default remains `full`, selecting all steps. Both GUIs now start
  with `recommended` and preview enabled. Selecting a Windows Docker/WSL step
  doesn't bypass its existing prompts, prerequisites or non-interactive limits.
- `minimal` excludes agents, Docker and Windows WSL. `work` selects the same
  steps as `recommended`; neither profile bypasses organization policy.
- Profiles add their exclusions to `--skip` / `-Skip` and can't be combined
  with `--only` / `-Only`. Selecting runtimes doesn't select Docker packages.
- Doctor is a full inventory, not filtered by profile. A no-Docker profile can
  still report Docker/Colima missing and exit 1. Successful installation isn't
  automatic verification; use explicit version checks in a new terminal.
- The agents step supports Claude Code and Codex. Retired gajae-code (`gjc`)
  and lazycodex aren't installed or deleted, and their existing configuration
  is preserved. Hermes is opt-in on macOS/Linux, not a default requirement.
- Automatic uninstall is retired. The old entrypoints stop with a nonzero exit and
  perform no deletion; uninstall flags and groups are no longer supported.
  This pre-1.0 breaking change is recorded under Unreleased in the changelog.

## Not covered (may change in any release)

- The exact set and versions of installed tools (upstreams move; that's the point).
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
