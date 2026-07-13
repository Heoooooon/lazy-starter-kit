# Versioning & stability policy

This project follows [Semantic Versioning](https://semver.org/). This document
defines **what counts as the public interface** — i.e. what you can script
against and pin, and what a version number promises about it.

## The public interface (semver-covered)

Breaking any of these requires a **major** version bump:

| Surface | Examples |
|---|---|
| **CLI flags** | `--only`, `--skip`, `--dry-run`, `--yes`, `--profile`, `--doctor`, `--update`, `--list`, `--version`, `--with-gajae` (Windows: the `-PascalCase` equivalents) |
| **Step / group ids** | install steps (`prereqs`, `brew`/`packages`, `runtimes`, `shell`, `docker`, `git`, `agents`, `wsl`) and uninstall groups — the values accepted by `--only`/`--skip` |
| **Profile names** | `full`, `minimal`, `work` |
| **Managed-block markers** | `# >>> lazy-starter-kit:<tag> >>>` … `# <<< lazy-starter-kit:<tag> <<<` in `${ZDOTDIR-$HOME}/.zshrc`, `${ZDOTDIR-$HOME}/.zprofile`, PowerShell profiles — tools and users may key on these |
| **Environment variables** | `STARTER_KIT_BRANCH` (pin a ref), `HERMES=0` (skip the Hermes agent), `ZDOTDIR` (non-empty absolute Zsh config directory), `ASSUME_YES`/CI non-interactive behavior |
| **Exit codes** | `0` success / `1` failure; `--doctor` exits `0` when nothing is missing (PATH-only warnings don't fail) and `1` when something is — CI enforces this contract |
| **Backup behavior** | the one-time `.bak` backup before the first managed edit of a config file |

**Minor** versions may: add tools to the default set, add steps/flags/profiles,
change log wording, change *which versions* of tools get installed.
**Patch** versions fix bugs without interface changes.

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
| **Tier 1** | macOS 14+ (Apple Silicon) · Windows Server 2025 (≈ Windows 11) · Ubuntu 24.04 · Fedora (latest) · Arch (latest) · openSUSE Tumbleweed | Full install → verify → uninstall runs in CI **on every commit**, plus idempotency (second install) and upgrade-path (previous tag → main) tests |
| **Tier 2** | Windows 10 1809+ / 11 desktop · Debian 12+ · RHEL 9 / Rocky / Alma · openSUSE Leap · WSL2 (Ubuntu) · Intel Macs | Expected to work (same code paths), not automatically tested; regressions fixed with priority when reported |
| **Unsupported** | Alpine / musl distros · 32-bit systems | Upstream tools (node, ast-grep, bun) don't ship builds |

A weekly scheduled CI run re-tests Tier 1 against moving upstreams; failures
automatically open a [`ci-drift`](https://github.com/Heoooooon/lazy-starter-kit/issues?q=label%3Aci-drift) issue.
