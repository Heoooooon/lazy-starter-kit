<div align="center">

### Start AI coding on Windows.

_v0.14.0 default: Git · Node LTS/npm · Claude Code · Codex · safety hooks · minimal PATH. Explicit developer profiles remain available._

**[← Back to repo root](../README.md)** · [macOS kit](../README.md) · [Linux kit](../linux/README.md)

</div>

---

> **🇰🇷 한국어 빠른 시작**: [v0.14.0 GUI ZIP](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.14.0/lazy-starter-kit-windows-gui.zip)을
> 풀고 `Lazy-Starter-Kit-Installer.cmd`를 여세요. 기본 구성은 `ai`, 기본 동작은
> 설치이며 미리보기는 별도 버튼입니다. Docker와 WSL은 제외됩니다.
> 일반 무프로필 CLI 설치도 `ai`입니다. 명시적 `recommended`는 더 넓은 개발
> 구성을 유지합니다. 설치 후 새 PowerShell에서 `-Profile ai -Doctor`로 확인하세요.
> 단독 `-Doctor`는 전체 목록 점검이므로 AI 검사에는 프로필을 반드시 넣으세요.
> 로그인과 첫 프롬프트 전송은 직접 합니다. [AI 안내](../README.md#ai-setup)를 참고하세요.
> v0.14.0은 자동 제거를 지원하지 않고 gajae-code (`gjc`), lazycodex를
> 설치하거나 기존 도구와 설정을 삭제하지 않습니다.
> 설치가 끝나면 PowerShell을 새로 여세요. [한국어 추천 설치 안내](../README.md#recommended-setup)

## Quick start

### AI setup (v0.14.0)

**Start with the [v0.14.0 GUI](#gui-download) or [pinned source](#install-from-source)
below.** v0.13.0 already had the broader `recommended` profile and first-use
guidance, but not the smaller AI default or the new GUI first-run flow.

The v0.14.0 GUI and ordinary no-profile CLI installs default to `ai`.
**Install** is the primary GUI action; **Preview** is a separate action that
makes no changes. Explicit `recommended`, `full`, `minimal`, and `work` keep their
existing developer payloads. There is no removal UI or automatic uninstall.

**Before installation:** downloads and AI services need internet access. Claude
Code needs a Claude account with service access or supported API credentials;
Codex needs a ChatGPT account with access or supported API credentials. Installing
the tools doesn't include subscriptions or credits. Review provider terms,
billing, and organization policy. The new GUI shows these requirements before
you install.

For CLI use, follow the [source commands](#install-from-source) below. Inspect
the local installer and scripts before previewing or installing. Follow the
prerequisite guidance; don't change policy to work around IT restrictions.

After installation, open a new PowerShell window and run the AI result check
from the v0.14.0 source's `windows` folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Profile ai -Doctor
```

Git, Node, npm, Claude Code, and Codex must actually run and pass their version
checks. Missing executables or failed probes mean **action needed**, not
**ready**. Neither preview nor a successful installer exit alone verifies this.
Local checks don't test authentication or a live provider session. Fix reported
blockers, then rerun the same `ai` profile. Continue with [First run](#first-run).

<a id="gui-download"></a>

### v0.14.0 GUI download

- [Download the v0.14.0 guided GUI installer](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.14.0/lazy-starter-kit-windows-gui.zip)

Extract the ZIP and double-click `Lazy-Starter-Kit-Installer.cmd`. The GUI starts
with **ai** and **Install** as the primary action. **Preview** is a separate
button for reviewing the plan without installing. Preview, failed or cancelled
installation, and incomplete readiness checks don't unlock first-run controls.
After installation and successful checks, open a new PowerShell
window and check versions before starting your [first project](../README.en.md#first-project).
Release GUIs use their pinned release commit, not mutable `main`. See the
[v0.14.0 release page](https://github.com/Heoooooon/lazy-starter-kit/releases/tag/v0.14.0)
for changes and all assets. The standard remote bootstrap chooses the newest
release tag unless a ref is selected; a release GUI stays pinned to its own
release. Later changes to `main` don't update a downloaded ZIP.

The GUI runs the shared PowerShell installer with `-Yes`.
`recommended` excludes Docker and WSL. Choosing `full` adds those steps, but
`-Yes` skips **new Docker Desktop and WSL/Ubuntu installations**. Existing Ubuntu
can still be initialized or receive the Linux kit as root. Review the preview
log before applying that profile.

v0.14.0 neither installs nor deletes gajae-code (`gjc`), lazycodex, or their
existing configuration. Automatic uninstall isn't supported. v0.13.0 used
recommended + preview in the GUI and full for no-profile CLI installs.
Older v0.12.0
still installs those agents, has no recommended profile, and retains the old
uninstall behavior. Its GUI starts with full + preview; don't use it for this setup.

<a id="install-from-source"></a>

### v0.14.0 source: AI setup

For a local source copy, open **PowerShell** (Windows PowerShell 5.1 or PowerShell
7) in a fresh folder. If Git is already available:

```powershell
git clone --branch v0.14.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0
cd lazy-starter-kit-v0.14.0\windows
# Inspect install.ps1 and scripts/ before running:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Profile ai -DryRun # preview
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Profile ai         # install
```

Without Git, [download the v0.14.0 source ZIP](https://github.com/Heoooooon/lazy-starter-kit/archive/refs/tags/v0.14.0.zip),
extract it, and open PowerShell in `lazy-starter-kit-0.14.0\windows`. Inspect the
installer and scripts, then run the same preview and apply commands above.
This source archive is different from the GUI ZIP.

These commands pin v0.14.0, the same release as the GUI above, and explicitly
select `ai`, also the ordinary no-profile install default. Use `recommended`
for the broader developer bundle, not as an alias for `ai`.

> If scripts are blocked, try a process-scoped bypass for the local preview:
> `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Profile ai -DryRun`
> Organization policy may still block execution; ask your administrator if so.
> After reviewing the plan, remove only `-DryRun` to apply. During installation,
> the prerequisites step tries to set CurrentUser `RemoteSigned` for Restricted
> or Undefined policies and asks before changing AllSigned. Adjustment can fail;
> it doesn't guarantee that future scripts will run.

**Requirements**: Windows 10 (1809+) or Windows 11 with **winget** (App Installer).
If `winget` is missing, install *App Installer* from the Microsoft Store first.

## What you get

### Default `ai`

Git, **winget `OpenJS.NodeJS.LTS` with npm**, Claude Code, Codex, safety hooks and
`lazy-safe-rm`, minimal PATH setup, and required prerequisites. Git for Windows
also provides Git Bash for the agents and safety hooks. No Python, Go, Rust,
Docker, WSL, Bun, uv, shell cosmetics, fonts, or optional CLI bundle.

### Explicit developer profiles

`recommended` keeps `prereqs,packages,runtimes,shell,git,agents` and the broader
payload below, without Docker or WSL. **It isn't an alias for `ai`.** `full` adds
Docker and WSL; `minimal` keeps the tools/runtimes/shell/Git bundle without agents,
Docker, or WSL; `work` keeps the same steps as `recommended`. Neither `minimal`
nor `work` is smaller than `ai`. Existing Docker/WSL consent rules still apply,
including the existing-Ubuntu behavior documented below. Hermes has no native
Windows installer; its advanced Linux opt-in is described below.

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

Developer steps run in this order; explicit `ai` narrows their payload as above:

```
prereqs  packages  runtimes  shell  docker  git  agents  wsl
```

```powershell
.\install.ps1 -DryRun               # change nothing, just print
.\install.ps1 -Yes                  # non-interactive, accept defaults
.\install.ps1 -Only packages,shell  # run a subset
.\install.ps1 -Skip agents          # run all but one
.\install.ps1 -NoAgents             # alias for -Skip agents
.\install.ps1 -Profile ai           # ordinary no-profile install default since v0.14.0
.\install.ps1 -Profile recommended  # broader developer bundle, without Docker/WSL
.\install.ps1 -Profile full         # all steps; no-profile default in v0.13.0 and earlier
.\install.ps1 -Profile minimal      # preset: prereqs packages runtimes shell git (no docker/agents/wsl)
.\install.ps1 -Profile work         # preset: everything except docker + wsl
.\install.ps1 -List                 # print step ids
.\install.ps1 -Version              # print the kit version
.\install.ps1 -Profile ai -Doctor   # AI executable checks; explicit profile required
.\install.ps1 -Update -Profile recommended # update a Git checkout, then re-run the developer profile
```

In v0.14.0, **`-Profile ai -Doctor` is required for AI scope**. It executes the
required commands and fails if one is missing or can't run; it doesn't test
provider login. Bare `-Doctor` and explicit developer profiles keep the full
tool/config inventory used by every doctor run in v0.13.0. Intentionally omitted
tools can be reported missing and cause exit 1. Don't install them just to make
the report green; use version checks for the tools you selected. Windows doesn't
expose the macOS `--doctor-json` flag.

Custom `-Only` and unprofiled `-Skip` selections keep their existing broader step
payloads, not the smaller `ai` payload. Profiles combine with `-Skip`, not `-Only`.
Unknown profiles or step IDs fail with a list of valid names; use `-List` for this
platform's steps. `-Update` requires a Git checkout, not a source ZIP.

Every step is **idempotent**, safe to re-run. Your PowerShell profile
(`$PROFILE.CurrentUserAllHosts`) is edited via a clearly marked managed block
(`# >>> lazy-starter-kit:main >>>`) that gets replaced (never duplicated) on
re-runs. Existing files you own are preserved.

The agents step installs the Codex/Claude Code recursive-`rm` guard.
`lazy-safe-rm.cmd` delegates guarded workspace cleanup to Git Bash, installed
with Git for Windows. Review and approve the hook when Codex first asks.

## Design notes

The broader runtime and shell details here apply to explicit developer profiles.
The `ai` runtime uses winget `OpenJS.NodeJS.LTS` with npm, not mise or rustup.

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
- **Hermes Agent** has no native Windows build. In an existing WSL2 distro,
  use a reviewed v0.14.0 Linux source checkout and explicitly opt into the
  advanced agents setup, for example `HERMES=1 ./install.sh --profile recommended`
  from its `linux` folder. The `wsl` step doesn't enable Hermes. Linux `ai`
  intentionally ignores even an inherited `HERMES=1`.

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

> An explicit `full` run **includes** `wsl`; `recommended` and the `ai`
> default don't. The unprofiled v0.13.0 CLI used full. Under `-Yes`
> or redirected input, only **new installation/registration** is skipped.
> Existing Ubuntu can still be initialized, and the Linux-kit offer defaults to
> Yes. Use `-Profile recommended` or `-Skip wsl` to leave the entire step out.

## First run

After checks pass, choose Claude Code or Codex in the v0.14.0 GUI and
explicitly launch a **new, empty practice folder**. Prompt copy puts the starter
request on your clipboard; it doesn't send it. Login and submission stay manual.

For a manual session, create a new empty folder in File Explorer. If its name
already exists, choose another name. Don't use your home folder, the kit checkout,
or an existing project. Open PowerShell there, run `git init`, then `claude` or
`codex`. Complete the provider's login yourself and review any safety-hook
approval request. Copy, review, and manually submit this prompt:

> Create a single-file breakout game named index.html in this practice folder that I can open directly in a browser. Don't overwrite or delete existing files. If index.html already exists, stop and ask for another name. Explain how to open the finished file.

Review proposed changes and commands before accepting them. Once the file is
created, open it in your browser. Font selection, `gh auth login`, PowerShell
autosuggestions, Docker, and WSL apply only if you installed those optional tools.
None is required for the first AI session.

## Automatic uninstall is not supported

v0.14.0 keeps the no-uninstall policy introduced in v0.13.0. The legacy
`windows/uninstall.ps1` entrypoint stops with an explanation and exit code 2,
without changing or removing anything. The kit can't reliably distinguish tools
it installed from tools you already had. For individual removals, follow the
tool's official instructions and review your PowerShell profile manually.

## Troubleshooting

For the default AI setup, start with `-Profile ai -Doctor`, fix reported
blockers, and rerun `-Profile ai`. A required tool skipped because of permissions
still needs attention. Custom `-Only` repairs below target the broader developer
steps and can install more than `ai`.

- **`winget` not recognized**: install *App Installer* from the Microsoft Store
  ([link](https://apps.microsoft.com/detail/9nblggh4nns1)), then reopen PowerShell.
- **"running scripts is disabled on this system"**: preview the local copy with
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Profile ai -DryRun`.
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

## Verification scope

Portable PowerShell parser, profile, onboarding, and packaged-bootstrap checks
aren't native Windows E2E. They don't establish native WinForms/DPI behavior,
console and registry PATH notification, winget/CMD/taskkill integration, or
PowerShell 5.1 execution. Provider authentication and prompt delivery aren't
verified by local readiness checks. Native CI and manual Windows checks must be
reported separately from portable results.

## License

MIT. See [../LICENSE](../LICENSE).
