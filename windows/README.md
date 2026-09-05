<div align="center">

### Set up a Windows development environment with a preview first.

_winget packages · runtimes · PowerShell profile · Git · Codex and Claude Code. Docker and WSL are optional._

**[← Back to repo root](../README.md)** · [macOS kit](../README.md) · [Linux kit](../linux/README.md)

</div>

---

> **🇰🇷 한국어 빠른 시작**: [v0.13.0 GUI ZIP](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.13.0/lazy-starter-kit-windows-gui.zip)을
> 풀고 `Lazy-Starter-Kit-Installer.cmd`를 여세요. 기본값은 recommended + 미리보기입니다.
> 로그를 확인한 뒤 미리보기를 끄고 적용하세요. 추천 구성은 Docker와 WSL을 제외합니다.
> CLI 기본값은 여전히 full이며, 아래 소스 예제는 v0.13.0 태그를 사용합니다.
> v0.13.0은 자동 제거를 지원하지 않고 gajae-code (`gjc`), lazycodex를
> 설치하거나 기존 도구와 설정을 삭제하지 않습니다.
> 설치가 끝나면 PowerShell을 새로 여세요. [한국어 추천 설치 안내](../README.md#recommended-setup)

## Quick start

### Recommended: v0.13.0 GUI

- [Download the v0.13.0 guided GUI installer](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.13.0/lazy-starter-kit-windows-gui.zip)

Extract the ZIP and double-click `Lazy-Starter-Kit-Installer.cmd`. The GUI starts
with **recommended + preview**. Review the selected components and preview log,
then turn preview off to install. After installation, open a new PowerShell
window and check versions before starting your [first project](../README.en.md#first-project).
Release GUIs use their pinned release commit, not mutable `main`. See the
[v0.13.0 release page](https://github.com/Heoooooon/lazy-starter-kit/releases/tag/v0.13.0)
for changes and all assets.

The GUI runs the shared PowerShell installer with `-Yes`.
`recommended` excludes Docker and WSL. Choosing `full` adds those steps, but
`-Yes` skips **new Docker Desktop and WSL/Ubuntu installations**. Existing Ubuntu
can still be initialized or receive the Linux kit as root. Review the preview
log before applying that profile.

v0.13.0 neither installs nor deletes gajae-code (`gjc`), lazycodex, or their
existing configuration. Automatic uninstall isn't supported. Older v0.12.0
still installs those agents, has no recommended profile, and retains the old
uninstall behavior. Its GUI starts with full + preview; don't use it for this setup.

### v0.13.0 source: recommended setup

For a local source copy, open **PowerShell** (Windows PowerShell 5.1 or PowerShell
7) in a fresh folder. If Git is already available:

```powershell
git clone --branch v0.13.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.13.0
cd lazy-starter-kit-v0.13.0\windows
# Inspect install.ps1 and scripts/ before running:
.\install.ps1 -Profile recommended -DryRun # preview
.\install.ps1 -Profile recommended         # apply without Docker or WSL
```

Without Git, [download the v0.13.0 source ZIP](https://github.com/Heoooooon/lazy-starter-kit/archive/refs/tags/v0.13.0.zip),
extract it, and open PowerShell in `lazy-starter-kit-0.13.0\windows`. Inspect the
installer and scripts, then run the same preview and apply commands above.
This source archive is different from the GUI ZIP.

These source commands pin v0.13.0, the same release as the GUI above. The recommended
steps are `prereqs,packages,runtimes,shell,git,agents`. With no profile switch, the
CLI still selects `full`.

> If scripts are blocked, try a process-scoped bypass for the local preview:
> `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Profile recommended -DryRun`
> Organization policy may still block execution; ask your administrator if so.
> After reviewing the plan, remove only `-DryRun` to apply. During installation,
> the prerequisites step tries to set CurrentUser `RemoteSigned` for Restricted
> or Undefined policies and asks before changing AllSigned. Adjustment can fail;
> it doesn't guarantee that future scripts will run.

**Requirements**: Windows 10 (1809+) or Windows 11 with **winget** (App Installer).
If `winget` is missing, install *App Installer* from the Microsoft Store first.

## What you get

| Layer | Tools |
|---|---|
| **Base** | winget (App Installer), TLS 1.2, conditional CurrentUser execution-policy adjustment |
| **CLI** | git, gh, jq, ripgrep, fd, bat, fzf (`tree`/`curl` are built into Windows) |
| **Shell** | PowerShell profile with **starship** prompt · **PSReadLine 2.2+** inline autosuggestions + list predictions (the `zsh-autosuggestions` equivalent) · **CompletionPredictor** (command-based predictions) · Tab completion menu + history-substring search on ↑/↓ · **PSFzf** (Ctrl-T/Ctrl-R) · JetBrainsMono Nerd Font |
| **Runtimes** | **mise** → node (LTS), python, go, **ast-grep** · **rustup** → rust + rust-analyzer · **uv** · **bun** |
| **Containers** | **Docker Desktop** (optional; needs WSL2/virtualization) |
| **Git/GitHub** | identity (GitHub noreply email), HTTPS credential helper, `core.autocrlf`, sane defaults |
| **AI agents** | **Claude Code** (`claude`) and **Codex** (`codex`). Hermes is a separate opt-in inside WSL2, not a native Windows installation. |

Open a new PowerShell window after installation and check `codex --version` and
`claude --version`. Follow the [first-project guide](../README.en.md#first-project)
and sign in through your chosen agent. An installer exit code alone doesn't
verify every tool or authenticate your accounts.

## Steps & flags

Steps run in this order:

```
prereqs  packages  runtimes  shell  docker  git  agents  wsl
```

```powershell
.\install.ps1 -DryRun               # change nothing, just print
.\install.ps1 -Yes                  # non-interactive, accept defaults
.\install.ps1 -Only packages,shell  # run a subset
.\install.ps1 -Skip agents          # run all but one
.\install.ps1 -NoAgents             # alias for -Skip agents
.\install.ps1 -Profile recommended  # core tools + agents, without Docker/WSL
.\install.ps1 -Profile full         # preset: everything (same as no switch)
.\install.ps1 -Profile minimal      # preset: prereqs packages runtimes shell git (no docker/agents/wsl)
.\install.ps1 -Profile work         # preset: everything except docker + wsl
.\install.ps1 -List                 # print step ids
.\install.ps1 -Version              # print the kit version
.\install.ps1 -Doctor               # full inventory, not a profile-specific check
.\install.ps1 -Update               # pull the latest kit, then re-run
```

Doctor checks its full tool/config inventory regardless of the selected profile.
Tools you intentionally skipped can be reported missing; don't install them just
to make the report green. Use explicit version checks for your selected tools.

Every step is **idempotent**, safe to re-run. Your PowerShell profile
(`$PROFILE.CurrentUserAllHosts`) is edited via a clearly marked managed block
(`# >>> lazy-starter-kit:main >>>`) that gets replaced (never duplicated) on
re-runs. Existing files you own are preserved.

The agents step installs the Codex/Claude Code recursive-`rm` guard.
`lazy-safe-rm.cmd` delegates guarded workspace cleanup to Git Bash, installed
with Git for Windows. Review and approve the hook when Codex first asks.

## Design notes

- **winget-first.** Plain tools come from winget; the runtimes are managed by
  **mise** (node/python/go/ast-grep) and **rustup** (rust) so versions are easy
  to switch. `ast-grep` is installed via mise's `ubi` backend to match the
  macOS/Linux kits.
- **Permissions depend on the package and machine policy.** Some winget packages
  may need administrator approval. Docker Desktop needs virtualization and may
  need a reboot. It is strictly opt-in: it defaults to **No**, is **never**
  installed under `-Yes` or
  non-interactively (licensing), and must be confirmed with an explicit `y` in an
  interactive run (e.g. `.\install.ps1 -Only docker`).
- **PATH refresh.** winget puts new tools on the persistent PATH; the installer
  re-reads the environment mid-run so later steps see them without a restart.
  Still, **open a new PowerShell window** afterwards to load the profile.
- **Runtimes shadow, never replace.** node/python/go from another source
  (system MSI, nvm-windows, scoop) are left alone; mise's win on PATH. Verify
  with `Get-Command node -All`.
- **Hermes Agent** has no native Windows build. If you want it, install it inside
  an existing WSL2 distro:
  `wsl bash -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup'`
  The `wsl` step doesn't enable Hermes. The Linux kit only installs it when
  `HERMES=1` is explicitly set in its Linux environment.

## WSL2 + Ubuntu (the `wsl` step)

The final step can stand up a full Linux environment on Windows and then run the
**lazy-starter-kit Linux installer inside it**, including `claude`, `codex`, mise,
and starship. Hermes remains opt-in and isn't enabled by this step.

Each run detects whether WSL is usable and Ubuntu is registered and runnable:

1. **New WSL/Ubuntu installation** needs an administrator PowerShell and explicit
   interactive consent (default **No**). `-Yes` and redirected input skip it.
2. **Registered Ubuntu, not initialized** can be initialized as root through
   `ubuntu install --root`. If the launcher isn't available, the step opens
   interactive setup or prints first-run guidance.
3. **Ready Ubuntu** gets an offer to run the Linux kit as root, skipping Docker.
   That offer defaults to **Yes**, including under `-Yes`. Output is streamed;
   Linux-kit failure is non-fatal. The bootstrap is downloaded from `main` unless
   `$env:STARTER_KIT_BRANCH` selects another ref. That bootstrap resolves its own
   checkout ref, so running Windows source doesn't guarantee the same source
   revision inside Ubuntu.

The pipeline stops for a required reboot, a declined installation, an error, or
lack of progress. Existing registered Ubuntu can be initialized and offered the
Linux kit in one run; registering a new distro still requires interactive consent.

```powershell
.\install.ps1 -Only wsl            # new installs ask; existing Ubuntu may be initialized
.\install.ps1 -Only wsl -DryRun    # print the staged plan for your current state
```

The **reboot-resume flow**: `wsl --install` may require a reboot. This step never
reboots you; it tells you to reboot and re-run `.\install.ps1 -Only wsl`, and the
next run picks up from wherever it left off (initialize → run the Linux kit).

> A default full CLI run **includes** `wsl`; recommended does not. Under `-Yes`
> or redirected input, only **new installation/registration** is skipped.
> Existing Ubuntu can still be initialized, and the Linux-kit offer defaults to
> Yes. Use `-Profile recommended` or `-Skip wsl` to leave the entire step out.

## Automatic uninstall is not supported

v0.13.0 doesn't provide automatic uninstall. The legacy
`windows/uninstall.ps1` entrypoint stops with an explanation and exit code 2,
without changing or removing anything. The kit can't reliably distinguish tools
it installed from tools you already had. For individual removals, follow the
tool's official instructions and review your PowerShell profile manually.

## Troubleshooting

- **`winget` not recognized**: install *App Installer* from the Microsoft Store
  ([link](https://apps.microsoft.com/detail/9nblggh4nns1)), then reopen PowerShell.
- **"running scripts is disabled on this system"**: preview the local copy with
  `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Profile recommended -DryRun`.
  Review the plan, then remove only `-DryRun` to apply the same profile. The bypass
  is process-scoped, but organization policy may still block it. Installation
  only tries to set CurrentUser `RemoteSigned` for Restricted or Undefined
  policies; changing AllSigned needs consent. Policy adjustment can fail, so
  contact your administrator if scripts remain blocked.
- **Autosuggestions don't appear**: you're likely on Windows PowerShell 5.1 with
  the old PSReadLine still loaded. Restart PowerShell once, or use **PowerShell 7**
  (`winget install Microsoft.PowerShell`) + **Windows Terminal**.
- **Behind a corporate proxy**: set `$env:HTTP_PROXY`/`$env:HTTPS_PROXY` before
  running; winget honors them. Some networks block winget's CDN; then install the
  few tools from your internal software portal instead.
- **Docker**: Docker Desktop is paid for larger orgs; prefer Docker/Podman inside
  WSL2 (see the Containers row). `wsl --install` needs virtualization enabled in BIOS.
- **Re-run anytime**: every step is idempotent; safe to run again after fixing a
  blocker (or use `-Only <step>` to redo just one).

## License

MIT. See [../LICENSE](../LICENSE).
