<div align="center">

<img src="./docs/images/lsk-hero.svg" alt="lazy-starter-kit — One line. Ready to build." width="100%" />

### Different machines, one starting line.

The fastest way to start AI coding on your own machine.

[![CI](https://github.com/Heoooooon/lazy-starter-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/Heoooooon/lazy-starter-kit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/Heoooooon/lazy-starter-kit?label=release&sort=semver&color=2ea043)](https://github.com/Heoooooon/lazy-starter-kit/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/OS-macOS%20·%20Linux%20·%20Windows-000000)](#)

[한국어](./README.md) · **English** · [Changelog](./CHANGELOG.md)

</div>

---

## What is this?

A fresh laptop or PC usually means installing Git, runtimes, terminal tools,
Docker, and AI coding agents one by one.

lazy-starter-kit bootstraps that development environment in one pass and gives
you a way to verify the result afterwards.

Main components include:

- CLI: git, gh, jq, ripgrep, fd, fzf, bat, tree, ast-grep, zoxide
- Runtimes: Node.js, Python, Go, Rust
- Shell/prompt: zsh, oh-my-zsh, starship, Nerd Font
- Containers: Colima on macOS, Docker Engine on Linux, optional Docker Desktop on Windows
- AI agents: Claude Code, gajae-code, Codex, lazycodex

Existing tools are left alone where practical, and managed configuration files
are edited only inside clearly marked blocks. Use `--doctor` to inspect the
current state and `--dry-run` to preview changes before applying them.

---

## Install

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/install.sh | bash
```

### Linux

Supports Ubuntu/Debian, Fedora/RHEL, Arch, and openSUSE families.

```bash
curl -fsSL https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/linux/install.sh | bash
```

Details: [linux/README.md](linux/README.md)

### Windows

From PowerShell:

```powershell
irm https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/windows/install.ps1 | iex
```

Details: [windows/README.md](windows/README.md)

GUI and double-click installers are available from
[Releases](https://github.com/Heoooooon/lazy-starter-kit/releases).

---

## Prefer to inspect it first?

If you do not want to execute a remote script immediately, clone the repository
and run a dry run first.

```bash
git clone https://github.com/Heoooooon/lazy-starter-kit.git
cd lazy-starter-kit
./install.sh --dry-run
```

Windows:

```powershell
git clone https://github.com/Heoooooon/lazy-starter-kit.git
cd lazy-starter-kit\windows
.\install.ps1 -DryRun
```

---

## Common options

macOS/Linux:

```bash
./install.sh --dry-run
./install.sh --doctor
./install.sh --update
./install.sh --only agents
./install.sh --skip docker
./install.sh --profile minimal
./install.sh --profile work
```

Windows uses PowerShell-style flags such as `-DryRun` and `-Only` instead of
`--dry-run` and `--only`.

Install steps are designed to be idempotent: re-running the installer should not
duplicate its managed configuration blocks.

---

## Verify after install

```bash
./install.sh --doctor
```

`--doctor` reports whether each tool is:

- installed and available
- installed but not on PATH
- missing

You can re-run only the affected step when needed.

```bash
./install.sh --only runtimes
./install.sh --only agents
```

---

## Automatic uninstall is not supported

**lazy-starter-kit does not provide automatic uninstall functionality.**

Older versions included uninstall scripts, but that behavior has been retired.
After installation, the kit cannot reliably determine which tools it installed
itself and which tools already belonged to the user.

For example, if Codex, Claude Code, Homebrew packages, mise, or oh-my-zsh were
already present before running the kit, deleting software solely by package name
or path could remove an existing development environment, configuration, auth
state, or user data.

The current policy is therefore:

- The kit does not automatically remove packages or developer tools.
- Legacy entrypoints `uninstall.sh`, `linux/uninstall.sh`, and
  `windows/uninstall.ps1` perform no deletion and stop immediately.
- To remove a specific tool, use that tool's official uninstall instructions.
- For `.zshrc`, `.zprofile`, or PowerShell profiles, inspect and manually remove
  the blocks marked `lazy-starter-kit` if you no longer want them.

Automatic removal will not be reintroduced until the installer can reliably
record and enforce ownership of everything it creates.

---

## Safety design

- **Dry run**: preview planned changes before applying them.
- **Existing config protection**: managed blocks are used instead of replacing entire user config files.
- **Fail closed on damaged markers**: malformed managed-block markers cause config edits to be refused.
- **Config backup**: a `.bak` backup is created before the first managed edit of a file.
- **Recursive-delete boundaries**: internal cleanup rejects HOME, filesystem root, paths outside the allowed boundary, and symlink traversal.
- **AI shell guard**: an additional defense layer blocks recursive `rm` calls from Codex and Claude Code hooks.
- **Release-based install**: after bootstrap, installation code resolves against the newest release tag by default.
- **CI**: install and health verification run on macOS, Windows, Ubuntu, Fedora, Arch, and openSUSE.

This project still relies on external supply chains including Homebrew,
npm/bun packages, and official installers maintained by upstream projects. See
[SECURITY.md](SECURITY.md) for the security scope and reporting policy.

---

## If Node or Python is already installed

Existing runtimes are not removed. Node, Python, and Go can be installed through
mise as separate versions and configured to take precedence in new shells.

macOS/Linux:

```bash
which -a node
which -a python
```

Windows:

```powershell
Get-Command node -All
Get-Command python -All
```

---

## Corporate machines

Use the work profile for a lighter setup.

```bash
./install.sh --profile work
```

Windows:

```powershell
.\install.ps1 -Profile work
```

Items that cannot be installed because of missing admin rights or company policy
are skipped or reported. On systems restricted by AppLocker, MDM, proxies, or
other organizational controls, follow your organization's IT policy.

---

## Development / contributing

- Design: [DESIGN.md](DESIGN.md)
- Versioning policy: [VERSIONING.md](VERSIONING.md)
- Security policy: [SECURITY.md](SECURITY.md)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)

```bash
./install.sh --dry-run
./install.sh --doctor
```

CI checks shell syntax, shellcheck/PSScriptAnalyzer, installation, idempotency,
doctor behavior, upgrade paths, and key safety regressions.

---

## License

MIT — [LICENSE](LICENSE)
