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

The v0.14.0 `ai` default prepares **Git, Node.js LTS/npm, Claude Code,
Codex, safety hooks and minimal PATH setup**, plus the prerequisites needed to
install them. It doesn't include Python, Go, Rust, Docker, Bun, uv, shell
cosmetics, fonts, or the optional CLI bundle.

**Start with v0.14.0:** use the [release downloads or pinned source commands](#recommended-setup)
below for the smaller AI setup and guided first run. v0.13.0 already had a
`recommended` developer profile and first-use guidance, but not the `ai` default
or the new GUI flow.

The explicit `recommended` profile keeps its broader developer bundle:

- CLI: git, gh, jq, ripgrep, fd, fzf, bat, tree, ast-grep, zoxide
- Runtimes: Node.js, Python, Go, Rust
- Shell/prompt: zsh and oh-my-zsh on macOS/Linux, PowerShell on Windows, starship, Nerd Font
- AI agents: Claude Code (`claude`) and Codex (`codex`)

Docker is excluded, as is WSL on Windows. Hermes is an advanced macOS/Linux
opt-in, for example `HERMES=1 ./install.sh --profile recommended` from a reviewed
source checkout (use `./linux/install.sh` on Linux). `ai` intentionally ignores
even an inherited `HERMES=1`; there's no native Windows Hermes installer.
The current kit neither installs nor deletes retired agents
such as gajae-code (`gjc`) and lazycodex, or their existing configuration.

Existing tools are left alone where practical, and managed configuration files
are edited only inside clearly marked blocks. Use `--doctor` to inspect the
current state and `--dry-run` to preview changes before applying them.

---

<a id="ai-setup"></a>

## AI setup (v0.14.0)

Ordinary GUI and CLI installs with no profile or custom step selection now use
`ai`. Explicit `recommended`, `full`, `minimal`, and `work` keep their existing
payloads. **`recommended` isn't an alias for `ai`**: it still installs the wider
developer bundle without Docker or Windows WSL.

| OS | Node.js LTS in `ai` |
|---|---|
| macOS | Homebrew `node@24`, including npm |
| Linux | mise `node@lts`, including npm |
| Windows | winget `OpenJS.NodeJS.LTS`, including npm |

**Why are Node.js and npm needed?** npm installs Codex, and Node.js runs the
safety-hook installer and the AI tools' safety hooks. You do not need to choose
an execution tool to get started. Follow the installation instructions for your
OS below.

<details>
<summary>Tool terms explained: Node.js, npm, Bun, bunx, mise</summary>

| Name | What it does |
|---|---|
| Node.js | Runs programs written in JavaScript. |
| npm | Usually comes with Node.js and downloads project packages or CLI tools. |
| Bun | Installs packages and runs JavaScript and TypeScript programs. |
| bunx | Comes with Bun. Finds and runs a CLI tool, downloading it if needed. |
| mise | Installs and selects versions of development tools such as Node.js or Bun. |

**Installing and running are different.** Bun can install many of the packages
you get through npm, but some need additional installation settings or Node.js
to run. Installing a program with Bun does not guarantee it runs without Node.js.

**A definition does not mean the tool is included.** The current default `ai`
profile does not install Bun/bunx. Linux uses mise to install Node.js, while the
default macOS and Windows `ai` profiles do not install mise. Advanced profiles
have different scopes; check Preview before installation.

Learn more: [Bun package installation](https://bun.com/docs/pm/cli/install),
[bunx execution](https://bun.com/docs/pm/bunx), and
[mise version selection](https://mise.jdx.dev/getting-started.html).

</details>

**Before installation:** downloads and AI services need internet access. Claude
Code needs a Claude account with service access or supported API credentials;
Codex needs a ChatGPT account with service access or supported API credentials.
Installation doesn't include subscriptions, service access, or credits. Review
provider terms, billing, and your organization's policy first. The new GUI shows
these requirements before installation.

In the v0.14.0 GUI, **Install** is the primary action. **Preview** is a
separate action that makes no changes. Neither a completed preview nor a
successful installer exit alone means the machine is ready. Git, Node, npm,
Claude Code, and Codex must actually run and pass their version checks. A missing
executable or failed check means **action needed**, not **ready**. Local readiness
doesn't test authentication or a live provider session.

On a fresh Mac, follow any Xcode Command Line Tools or Homebrew prerequisite
instructions. If installation continues in Terminal, finish it there, then return
to the GUI's result check before starting a practice session. Use a fresh Terminal
window to check the installed PATH, not the pre-install shell.

For CLI installation, get the **v0.14.0 source** using the commands
[below](#recommended-setup), inspect the installer and its scripts, then use
only your OS's row from that source root:

| OS | Preview | Install | Check in a new terminal |
|---|---|---|---|
| macOS | `bash ./install.sh --profile ai --dry-run` | `bash ./install.sh --profile ai` | `bash ./install.sh --profile ai --doctor` |
| Linux | `bash ./linux/install.sh --profile ai --dry-run` | `bash ./linux/install.sh --profile ai` | `bash ./linux/install.sh --profile ai --doctor` |
| Windows | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai -DryRun` | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai` | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai -Doctor` |

If a required tool is missing, review its log and fix the reported blocker, then
rerun the same `ai` profile. Custom `--only` / `-Only` or unprofiled `--skip` /
`-Skip` selections retain the wider developer-step payloads. Don't use them as a
smaller AI repair shortcut. Unknown profiles and step IDs are rejected with a
list of valid names; profiles and `--only` / `-Only` can't be combined.

After checks pass, choose Claude Code or Codex and explicitly launch a **new,
empty practice folder** from the GUI. Prompt copy places the starter request on
the clipboard; it doesn't submit it. Sign in, review the prompt, and send it
yourself. There is no automatic uninstall or removal UI. The manual equivalent
is in [First project](#first-project).

---

<a id="recommended-setup"></a>

## Recommended setup (v0.14.0)

**New to this? On macOS, use the v0.14.0 GUI below. The Windows GUI is experimental.**
The default `ai` profile sets up Claude Code and Codex without Docker or Windows
WSL. v0.14.0 neither installs nor deletes gajae-code (`gjc`), lazycodex, or their
existing configuration. It doesn't provide automatic uninstall.

<a id="gui-downloads"></a>

### GUI downloads

| OS | v0.14.0 GUI asset | Open after extracting |
|---|---|---|
| macOS 14+, Apple Silicon or Intel | [lazy-starter-kit-macos-gui.zip](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.14.0/lazy-starter-kit-macos-gui.zip) | `Lazy Starter Kit Installer.app` |
| Windows (experimental) | [lazy-starter-kit-windows-gui.zip](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.14.0/lazy-starter-kit-windows-gui.zip) | `Lazy-Starter-Kit-Installer.cmd` |
| Linux | No GUI package | Use the v0.14.0 source commands below or the [Linux guide](linux/README.md) |

**Windows is experimental:** automated tests and installation package verification
have passed. Manual verification on a real Windows PC has not covered the full
journey from double-clicking the launcher through installer screens, permission
prompts, installation completion, and first run.

The GUI starts with **ai**, with **Install** as the primary action and a separate
**Preview** button. Review the plan without installing, then choose Install when
ready. Ordinary CLI installs with no profile or custom steps also use `ai`.
The AI plan excludes `docker` and Windows `wsl`. Preview, failed or cancelled
installation, and incomplete readiness checks don't unlock first-run controls.
After installation and successful checks, continue with
[a new terminal, version checks and your first project](#first-project).
Account sign-in and the first prompt remain manual.

See the [v0.14.0 release page](https://github.com/Heoooooon/lazy-starter-kit/releases/tag/v0.14.0)
for changes and all assets. Packaged GUIs pin their own release commit; the
standard remote bootstrap resolves the newest release tag by default.
Changes to `main` don't automatically update release ZIPs.

**v0.13.0** used full for no-profile CLI installs and recommended + preview in
the GUI. Its explicit developer profiles and no-uninstall policy are preserved
in v0.14.0; its ZIPs don't acquire the new AI flow.

Older **v0.12.0** has no `recommended` profile and its GUIs start with full +
preview. It still installs gajae-code and lazycodex and includes the old automatic
uninstall behavior. Don't use it for the setup described here.

### Install from source (Linux or terminal users)

The commands below clone the **v0.14.0 tag** and run the local installer.
Install [Git](https://git-scm.com/downloads) first and open a new terminal, or
download the [v0.14.0 source ZIP](https://github.com/Heoooooon/lazy-starter-kit/archive/refs/tags/v0.14.0.zip),
extract it, and open a terminal in `lazy-starter-kit-0.14.0`. With the ZIP, skip
the clone and `cd` commands. Use a new folder rather than an existing checkout.

### 1. Inspect and preview

Open the installer and its `scripts/` folder in an editor before running it.
Preview prints the selected steps without installing them. Check that `docker`
and, on Windows, `wsl` are absent from the plan.

### macOS

```bash
git clone --branch v0.14.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0
cd lazy-starter-kit-v0.14.0
# Inspect install.sh and scripts/, then preview:
bash ./install.sh --profile ai --dry-run
```

### Linux

Ubuntu/Debian, Fedora/RHEL, Arch, and openSUSE families:

```bash
git clone --branch v0.14.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0
cd lazy-starter-kit-v0.14.0
# Inspect linux/install.sh and linux/scripts/, then preview:
bash ./linux/install.sh --profile ai --dry-run
```

Platform details: [Linux guide](linux/README.md).

### Windows

In PowerShell (5.1 or newer):

```powershell
git clone --branch v0.14.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0
cd lazy-starter-kit-v0.14.0
# Inspect windows/install.ps1 and windows/scripts/, then preview:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai -DryRun
```

`-ExecutionPolicy Bypass` applies only to this child process, not your saved
PowerShell policy. Company policy can still block execution; don't change it
to work around IT restrictions. Platform details: [Windows guide](windows/README.md).

### 2. Apply the reviewed plan

Stay in the same source folder and run **only your OS's command**:

| OS | Apply |
|---|---|
| macOS | `bash ./install.sh --profile ai` |
| Linux | `bash ./linux/install.sh --profile ai` |
| Windows | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai` |

Approve required system prompts only after reviewing them. macOS may require
Xcode Command Line Tools and Homebrew setup; follow the prerequisite guidance
and rerun the same command if asked. Review warnings and skipped steps. A
successful installer exit isn't proof that every tool is installed or signed in.
Continue with [a new terminal and your first project](#first-project).

---

## Common options

These explicit developer-profile options remain available in v0.14.0.
Run from the source root (replace `./install.sh` with
`./linux/install.sh` on Linux):

```bash
./install.sh --profile recommended --dry-run
./install.sh --profile recommended --doctor
./install.sh --update --profile recommended
./install.sh --only agents
./install.sh --skip docker
./install.sh --profile minimal
./install.sh --profile work
```

Windows uses `windows\install.ps1` with PowerShell-style flags such as `-DryRun`
and `-Only` instead of `--dry-run` and `--only`.

| Profile | Selection |
|---|---|
| `ai` (default) | Git, Node LTS/npm, Claude Code, Codex, safety hooks, minimal PATH and required prerequisites. Ordinary no-profile install and GUI default since v0.14.0. |
| `recommended` | Core tools, runtimes, shell, Git, Claude Code and Codex. No Docker or Windows WSL. Not an alias for `ai`. |
| `full` | All steps, including Docker and Windows WSL. Explicit opt-in in v0.14.0; the no-profile CLI default in v0.13.0 and earlier. Windows installation prompts and prerequisites still apply. |
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
Windows, so the installed PATH and shell configuration load. For the default
`ai` setup, run these commands and the profile check in [AI setup](#ai-setup):

```bash
git --version
node --version
npm --version
claude --version
codex --version
```

For the broader `recommended` setup:

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
account access. If one fails, review that install step's log. For `ai`, fix the
blocker and rerun the same profile. For a broader developer setup, rerun the step
from the source folder: `--only runtimes` or `--only agents` on macOS/Linux, or
`-Only runtimes` / `-Only agents` on Windows. Don't add `--profile` / `-Profile`
to an `--only` / `-Only` command.

Doctor scope in v0.14.0 is platform-specific:

- **macOS:** bare `--doctor` infers the saved install-profile marker, falling
  back to the full inventory if no recognized marker exists. Use
  `--profile ai --doctor` for AI executable and safety-hook checks, or
  `--profile ai --doctor-json` for the machine-readable result.
- **Linux:** bare `--doctor` defaults to AI executable checks. The explicit
  `--profile ai --doctor` command has the same scope.
- **Windows:** bare `-Doctor` still checks the full inventory. You must pass
  **`-Profile ai -Doctor`** for AI executable checks.

AI checks fail when a required command can't run; macOS also checks its safety
configuration. They don't verify provider login. Explicit developer profiles
keep the full tool/config inventory used by every doctor run in v0.13.0. It
reports installed, off-PATH and missing tools. A recommended, minimal or work
setup can report intentionally omitted Docker/Colima as missing and exit 1.
You don't need to install those tools just to make doctor green.

### 2. Start in a new, empty practice folder

Don't use your home directory, the kit checkout, or an existing project. On
macOS/Linux, this command starts Codex only if creating the new folder succeeds.
If the name is already taken, choose another name:

```bash
mkdir "$HOME/my-first-ai" && cd "$HOME/my-first-ai" && git init && codex
```

On Windows, create a new empty folder in File Explorer, open PowerShell there,
and run `git init`, then `codex`. Run `claude` instead if you prefer Claude Code.
In the v0.14.0 GUI, choose the agent and explicitly launch its new practice
folder. Use the prompt-copy action to place the starter request on the clipboard.

Follow the tool's own sign-in prompts; installing the kit doesn't create an
account or provide API credits. If Codex asks to approve the kit's shell-safety
hook, review it before approving. Copy, review, and manually submit a first request:

> Create a single-file breakout game named index.html in this practice folder that I can open directly in a browser. Don't overwrite or delete existing files. If index.html already exists, stop and ask for another name. Explain how to open the finished file.

Review proposed file changes and commands before accepting them. Open the new
file in your browser when it's ready. Login and prompt submission aren't automated.

---

## Automatic uninstall is not supported

**v0.14.0 doesn't provide automatic uninstall functionality.**

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

Existing runtimes aren't removed. The `ai` profile uses Homebrew
`node@24` on macOS, mise `node@lts` on Linux, and winget `OpenJS.NodeJS.LTS` on
Windows. Python isn't part of `ai`. The broader developer profiles keep mise for
Node, Python, and Go. Kit-installed runtimes can take precedence in new shells.

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

The v0.14.0 `work` profile excludes Docker and Windows WSL. It isn't a
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

Verification scope: portable PowerShell checks aren't native Windows E2E and
don't establish WinForms/DPI or Windows console/registry PATH behavior. Local
readiness and GUI checks don't verify provider authentication or prompt delivery.

---

## License

MIT. [LICENSE](LICENSE)
