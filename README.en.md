<div align="center">

<img src="./docs/images/lsk-hero.svg" alt="lazy-starter-kit. Ready to build." width="100%" />

*This illustration shows an older release's full-profile preview, not an installed or verified current recommended setup. Follow the [current recommended setup](#recommended-setup) below.*

### Different machines, one starting line.

The fastest way to start AI coding on your own machine.

[![CI](https://github.com/Heoooooon/lazy-starter-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/Heoooooon/lazy-starter-kit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/Heoooooon/lazy-starter-kit?label=release&sort=semver&color=2ea043)](https://github.com/Heoooooon/lazy-starter-kit/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/OS-macOS%20·%20Linux%20·%20Windows-000000)](#)

[한국어](./README.md) · **English** · [Recommended setup](#recommended-setup) · [First project](#first-project) · [Changelog](./CHANGELOG.md)

</div>

---

## What is this?

A fresh laptop or PC usually means installing Git, runtimes, terminal tools,
Docker, and AI coding agents one by one.

lazy-starter-kit bootstraps that development environment in one pass and gives
you a way to verify the result afterwards.

The v0.13.0 recommended setup includes:

- CLI: git, gh, jq, ripgrep, fd, fzf, bat, tree, ast-grep, zoxide
- Runtimes: Node.js, Python, Go, Rust
- Shell/prompt: zsh and oh-my-zsh on macOS/Linux, PowerShell on Windows, starship, Nerd Font
- AI agents: Claude Code (`claude`) and Codex (`codex`)

Docker is excluded, as is WSL on Windows. Hermes is opt-in on macOS/Linux
with `HERMES=1`, not part of the beginner setup; there's no native Windows
Hermes installer. The current kit neither installs nor deletes retired agents
such as gajae-code (`gjc`) and lazycodex, or their existing configuration.

Existing tools are left alone where practical, and managed configuration files
are edited only inside clearly marked blocks. Use `--doctor` to inspect the
current state and `--dry-run` to preview changes before applying them.

---

<a id="recommended-setup"></a>

## Recommended setup (v0.13.0)

**New to this? On macOS and Windows, use the v0.13.0 GUI below.**
The recommended profile sets up Claude Code and Codex without Docker or Windows
WSL. v0.13.0 neither installs nor deletes gajae-code (`gjc`), lazycodex, or their
existing configuration. It doesn't provide automatic uninstall.

<a id="gui-downloads"></a>

### GUI downloads

| OS | v0.13.0 GUI asset | Open after extracting |
|---|---|---|
| macOS 14+, Apple Silicon or Intel | [lazy-starter-kit-macos-gui.zip](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.13.0/lazy-starter-kit-macos-gui.zip) | `Lazy Starter Kit Installer.app` |
| Windows | [lazy-starter-kit-windows-gui.zip](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.13.0/lazy-starter-kit-windows-gui.zip) | `Lazy-Starter-Kit-Installer.cmd` |
| Linux | No GUI package | Use the v0.13.0 source commands below or the [Linux guide](linux/README.md) |

The GUI starts with **recommended + preview**. Review the selected components
and preview log before turning preview off and applying. The recommended plan
should omit `docker` and, on Windows, `wsl`. The CLI still defaults to **full**
when no profile is passed. After installation, continue with
[a new terminal, version checks and your first project](#first-project).
A successful installer exit doesn't verify every tool or account sign-in.

See the [v0.13.0 release page](https://github.com/Heoooooon/lazy-starter-kit/releases/tag/v0.13.0)
for changes and all assets. Packaged GUIs pin their own release commit; the
standard remote bootstrap resolves the newest release tag by default.
Changes to `main` don't automatically update release ZIPs.

Older **v0.12.0** has no `recommended` profile and its GUIs start with full +
preview. It still installs gajae-code and lazycodex and includes the old automatic
uninstall behavior. Don't use it for the setup described here.

### Install from source (Linux or terminal users)

The commands below clone the **v0.13.0 tag** and run the local installer.
Install [Git](https://git-scm.com/downloads) first and open a new terminal, or
download the [v0.13.0 source ZIP](https://github.com/Heoooooon/lazy-starter-kit/archive/refs/tags/v0.13.0.zip),
extract it, and open a terminal in `lazy-starter-kit-0.13.0`. With the ZIP, skip
the clone and `cd` commands. Use a new folder rather than an existing checkout.

### 1. Inspect and preview

Open the installer and its `scripts/` folder in an editor before running it.
Preview prints the selected steps without installing them. Check that `docker`
and, on Windows, `wsl` are absent from the plan.

### macOS

```bash
git clone --branch v0.13.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.13.0
cd lazy-starter-kit-v0.13.0
# Inspect install.sh and scripts/, then preview:
bash ./install.sh --profile recommended --dry-run
```

### Linux

Ubuntu/Debian, Fedora/RHEL, Arch, and openSUSE families:

```bash
git clone --branch v0.13.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.13.0
cd lazy-starter-kit-v0.13.0
# Inspect linux/install.sh and linux/scripts/, then preview:
bash ./linux/install.sh --profile recommended --dry-run
```

Platform details: [Linux guide](linux/README.md).

### Windows

In PowerShell (5.1 or newer):

```powershell
git clone --branch v0.13.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.13.0
cd lazy-starter-kit-v0.13.0
# Inspect windows/install.ps1 and windows/scripts/, then preview:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile recommended -DryRun
```

`-ExecutionPolicy Bypass` applies only to this child process, not your saved
PowerShell policy. Company policy can still block execution; don't change it
to work around IT restrictions. Platform details: [Windows guide](windows/README.md).

### 2. Apply the reviewed plan

Stay in the same source folder and run **only your OS's command**:

| OS | Apply |
|---|---|
| macOS | `bash ./install.sh --profile recommended` |
| Linux | `bash ./linux/install.sh --profile recommended` |
| Windows | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile recommended` |

Approve required system prompts only after reviewing them. macOS may require
Xcode Command Line Tools and Homebrew setup; follow the prerequisite guidance
and rerun the same command if asked. Review warnings and skipped steps. A
successful installer exit isn't proof that every tool is installed or signed in.
Continue with [a new terminal and your first project](#first-project).

---

## Common options

From the v0.13.0 source root (replace `./install.sh` with
`./linux/install.sh` on Linux):

```bash
./install.sh --profile recommended --dry-run
./install.sh --doctor
./install.sh --update --profile recommended
./install.sh --only agents
./install.sh --skip docker
./install.sh --profile minimal
./install.sh --profile work
```

Windows uses `windows\install.ps1` with PowerShell-style flags such as `-DryRun`
and `-Only` instead of `--dry-run` and `--only`.

| Profile | v0.13.0 selection |
|---|---|
| `recommended` | Core tools, runtimes, shell, Git, Claude Code and Codex. No Docker or Windows WSL. |
| `full` | All steps, including Docker and Windows WSL. Still the CLI default when no profile is passed. Windows installation prompts and prerequisites still apply. |
| `minimal` | Core tools, runtimes, shell and Git. No agents, Docker or Windows WSL. |
| `work` | Same steps as recommended; check your employer's policy before installing. |

Profiles combine with `--skip` / `-Skip`, not `--only` / `-Only`. On a source
ZIP, `--update` / `-Update` isn't available because it requires a Git checkout.

Install steps are designed to be idempotent: re-running the installer should not
duplicate its managed configuration blocks.

---

<a id="first-project"></a>

## First project

### 1. Open a new terminal and check versions

Open a **new Terminal window** on macOS/Linux, or a **new PowerShell window** on
Windows, so the installed PATH and shell configuration load. For recommended:

```bash
git --version
node --version
python --version
go version
rustc --version
codex --version
claude --version
```

These commands also work in PowerShell. They check command availability, not
account access. If one fails, review that install step's log before rerunning
it from the source folder. For example, use `--only runtimes` or `--only agents`
on the macOS/Linux installer, or `-Only runtimes` / `-Only agents` on Windows.
Don't add `--profile` / `-Profile` to an `--only` / `-Only` command.

`--doctor` / `-Doctor` is an optional **full inventory**, not a profile-specific
success check. It reports installed, off-PATH and missing tools. A recommended,
minimal or work setup can report intentionally omitted Docker/Colima as missing
and exit 1. You don't need to install those tools just to make doctor green.

### 2. Start in a project folder

In a folder where you keep projects, choose an unused folder name:

```bash
mkdir my-first-project
cd my-first-project
git init
codex
```

Run `claude` instead if you prefer Claude Code. Follow that tool's own sign-in
prompts; installing the kit doesn't create an account or provide API credits.
If Codex asks to approve the kit's shell-safety hook, review it before approving.
Try asking: "Create a simple hello-world page and explain how to run it."
Review proposed file changes and commands before accepting them.

---

## Automatic uninstall is not supported

**v0.13.0 doesn't provide automatic uninstall functionality.**

The older v0.12.0 release still has the old removal behavior. Don't use an
old release uninstaller to clean up an existing machine.

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
- **Explicit source or release**: a local checkout runs that source; the standard remote bootstrap resolves the newest release tag by default. Release GUIs pin their own commit.
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

The v0.13.0 `work` profile excludes Docker and Windows WSL. It isn't a
permission bypass. From the source root (use `./linux/install.sh` on Linux):

```bash
./install.sh --profile work
```

Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile work
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

MIT. [LICENSE](LICENSE)
