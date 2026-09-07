<div align="center">

### Start AI coding on Linux.

_v0.14.0 default: Git · Node LTS/npm · Claude Code · Codex · safety hooks · minimal PATH. Explicit developer profiles remain available._

**[← Back to repo root](../README.md)** · [macOS kit](../README.md) · [Windows kit](../windows/README.md)

</div>

---

> **🇰🇷 한국어 빠른 시작**: Linux는 GUI 없이 소스로 설치합니다. Git이 설치된
> 터미널에서 `v0.14.0` 태그를 새 폴더에 복제하고 기본 `ai` 구성을 미리 확인하세요.
> `lazy-starter-kit-v0.14.0` 폴더가 이미 있다면 다른 작업 폴더에서 시작하세요.
> 복제에 실패하면 다음 단계로 진행하지 마세요.
> ```sh
> git clone --branch v0.14.0 --depth 1 https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0 &&
>   cd lazy-starter-kit-v0.14.0/linux &&
>   ./install.sh --profile ai --dry-run
> ```
> 로그를 확인한 뒤 같은 터미널에서 아래 명령을 실행하면 Docker 없이 설치합니다:
> ```sh
> ./install.sh --profile ai
> ```
> Git이 없다면 [v0.14.0 소스 ZIP](https://github.com/Heoooooon/lazy-starter-kit/archive/refs/tags/v0.14.0.zip)을
> 풀고 `lazy-starter-kit-0.14.0/linux`에서 미리보기와 적용 명령을 실행하세요.
> v0.14.0의 일반 무프로필 설치 기본값은 `ai`입니다. 설치 후 새 터미널에서
> 같은 소스 폴더의 `./install.sh --profile ai --doctor`로 확인하세요.
> 단독 `--doctor`도 AI 실행 파일을 검사하며, 로그인은 직접 합니다.
> 명시적 `recommended`는 기존의 더 넓은 개발 구성을 유지합니다.
> v0.14.0은 자동 제거를 지원하지 않으며,
> gajae-code (`gjc`), lazycodex를 설치하거나 기존 도구와 설정을 삭제하지 않습니다.
> apt·dnf·pacman·zypper를 자동 감지합니다 (glibc 배포판; Alpine/musl 미지원).
> [한국어 추천 설치 안내](../README.md#recommended-setup)

## Quick start

### AI setup (v0.14.0)

**Use the v0.14.0 source commands [below](#install-from-source).** Ordinary
no-profile installs now use the smaller `ai` payload. Explicit `recommended`,
`full`, `minimal`, and `work` keep their existing developer payloads.

v0.13.0 already had the broader `recommended` profile and first-use guidance,
but its no-profile CLI default was `full`. Its downloads don't include `ai`.

**Before installation:** downloads and AI services need internet access. Claude
Code needs a Claude account with service access or supported API credentials;
Codex needs a ChatGPT account with access or supported API credentials. The kit
doesn't include subscriptions or credits. Review provider terms, billing, and
organization policy. Login and prompt submission are manual.

After installation, open a new terminal, return to the v0.14.0 source's `linux`
folder, and run `./install.sh --profile ai --doctor`. Git, Node, npm, Claude Code,
and Codex must actually run and pass their version checks. A missing executable
or failed probe needs attention, even if installation exited successfully.
Preview isn't a readiness check; local checks don't test authentication or a
live provider session. Fix reported blockers, then rerun the same `ai` profile.
Follow [First run](#first-run) below.

<a id="install-from-source"></a>

### Install from source: v0.14.0 AI setup

Linux has no GUI package. With Git available, clone the **v0.14.0 tag** into a
fresh directory and preview the default AI profile.
Start in a folder without an existing `lazy-starter-kit-v0.14.0` directory.
The `&&` chain stops if cloning or changing directories fails:

```sh
git clone --branch v0.14.0 --depth 1 https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0 &&
  cd lazy-starter-kit-v0.14.0/linux &&
  ./install.sh --profile ai --dry-run
```

Without Git, download the [v0.14.0 source ZIP](https://github.com/Heoooooon/lazy-starter-kit/archive/refs/tags/v0.14.0.zip),
extract it, and open a terminal in `lazy-starter-kit-0.14.0/linux`. Inspect
`install.sh` and `scripts/`, then run `./install.sh --profile ai --dry-run`.
After reviewing the preview, apply from the same terminal and directory:

```sh
./install.sh --profile ai # apply the small AI setup; no Docker
```

The v0.14.0 ordinary no-profile install defaults to `ai`. For a broader developer
setup, explicitly choose `recommended`; `full` adds Docker. `minimal` omits
agents and Docker; `work` selects the same steps as `recommended`.

These commands run the local release source, not mutable `main`. The standard
remote bootstrap chooses the newest release tag unless `STARTER_KIT_BRANCH`
selects a ref. Linux doesn't enforce `STARTER_KIT_COMMIT`; use a reviewed local
checkout for a full commit pin and don't run `--update` on it.

v0.14.0 neither installs nor deletes gajae-code (`gjc`), lazycodex, or their
existing configuration. Automatic uninstall isn't supported. Older v0.12.0
doesn't have the recommended profile or these policies; don't use it for this setup.
For macOS or Windows, the [v0.14.0 GUI downloads](../README.en.md#gui-downloads)
default to `ai`, with Install and Preview as separate actions.

**Supported distros** (auto-detected package manager): Debian/Ubuntu (`apt`),
Fedora/RHEL (`dnf`/`yum`), Arch (`pacman`), openSUSE (`zypper`), all **glibc**.
Alpine/musl (`apk`) is **not supported** (upstream node, ast-grep and bun ship
no musl builds). CI includes installation and verification jobs for Ubuntu,
Fedora, openSUSE and Arch. It doesn't run automatic uninstall.

## What you get

### Default `ai`

Git, **mise `node@lts` with npm**, Claude Code, Codex, safety hooks and
`lazy-safe-rm`, minimal PATH setup, and their required prerequisites. No Python,
Go, Rust, Docker, Bun, uv, shell cosmetics, fonts, or optional CLI bundle.
Ordinary no-profile CLI installs use `ai` since v0.14.0.

### Explicit developer profiles

`recommended` keeps `prereqs,packages,runtimes,shell,git,agents` and its broader
payload, without Docker. It isn't an alias for `ai`. `full` adds Docker;
`minimal` keeps the tools/runtimes/shell/Git bundle without Docker or agents;
`work` uses the same steps as `recommended`. These profiles retain their existing
payloads. Neither `minimal` nor `work` is smaller than `ai`. Hermes is an advanced
agent opt-in, for example `HERMES=1 ./install.sh --profile recommended` from this
Linux source folder. `ai` intentionally ignores even an inherited `HERMES=1`.
The table below describes these broader tools, not the default AI setup.

| Layer | Tools |
|---|---|
| **Base** | compiler/build tools, `git`, `curl`, `wget`, `unzip`, `zsh` (via your distro's package manager) |
| **CLI** | ripgrep, fd, bat, fzf, jq, tree, **gh** (GitHub CLI), zoxide |
| **Shell** | zsh + oh-my-zsh (plugins: git, npm, node, autosuggestions, syntax-highlighting), **starship** prompt |
| **Runtimes** | **mise** → node (LTS), python, go, **ast-grep** · **rustup** → rust + rust-analyzer · **uv** · **bun** |
| **Containers** | **Docker Engine** + compose/buildx (official `get.docker.com`, opt-in) |
| **Git/GitHub** | identity (GitHub noreply email), HTTPS credential helper, sane defaults |
| **AI agents** | **Claude Code** (`claude`) and **Codex** (`codex`). **Hermes Agent** (`hermes`) needs `HERMES=1` and a non-AI selection that includes `agents`. |

After installation, open a new terminal and check `codex --version` and
`claude --version`. Then follow the [first-project guide](../README.en.md#first-project)
and complete the chosen agent's own sign-in flow. An installer exit code alone
doesn't verify every tool or authenticate your accounts.

## Steps & flags

Developer steps run in this order; explicit `ai` narrows their payload as above:

```
prereqs  packages  runtimes  shell  docker  git  agents
```

```sh
./install.sh --dry-run             # change nothing, just print
./install.sh --yes                 # non-interactive, accept defaults
./install.sh --only packages,shell # run a subset
./install.sh --skip agents         # run all but one
./install.sh --no-agents           # alias for --skip agents
./install.sh --list                # print step ids
./install.sh --profile ai --doctor # AI executable checks; also the bare --doctor default
./install.sh --update --profile recommended # update a Git checkout, then re-run the developer profile
./install.sh --profile ai          # ordinary no-profile install default since v0.14.0
./install.sh --profile full        # broader bundle including Docker
./install.sh --profile recommended # broader bundle without Docker
./install.sh --profile work        # corporate PCs; same steps as recommended
```

In v0.14.0, bare `--doctor` and `--profile ai --doctor` check the required AI
executables and fail if a command is missing or can't run. They don't test
provider login. Explicit developer profiles retain the full tool/config
inventory that v0.13.0 used for all doctor runs. Intentionally omitted tools can
be reported missing and cause exit 1. Don't install them just to make the report
green; use version checks for the tools you selected. Linux doesn't expose the
macOS `--doctor-json` flag.

Custom `--only` and unprofiled `--skip` selections keep their existing, broader
step payloads, not the smaller `ai` payload. Profiles combine with `--skip`, not
`--only`. Unknown profiles or step IDs fail with a list of valid names; use
`--list` to see this platform's steps. `--update` requires a Git checkout and
isn't available in a source ZIP.

Every step is **idempotent**, safe to re-run. `${ZDOTDIR-$HOME}/.zshrc` is edited via clearly
marked managed blocks (`# >>> lazy-starter-kit:* >>>`) that get replaced (never
duplicated) on re-runs. Existing files you own are preserved.

The agents step also installs a Codex/Claude Code `PreToolUse` guard that blocks
recursive `rm` and provides `lazy-safe-rm` for strict descendants of the current
Git workspace. Recursive installer cleanup independently validates
physical containment and refuses root, HOME, boundary, outside, and symlink targets.

## Design notes

The wider runtime, CLI, shell, and Docker details here apply to the explicit
developer profiles. The `ai` runtime is only mise `node@lts` with npm.

- **No Homebrew.** Plain CLI utilities come from your distro's package manager;
  the "moving target" developer tools (mise, starship, uv, bun, rustup) are
  installed from their **official user-space installers** into `$HOME`, so the
  kit works the same across every distro and needs **no root** for them.
- **sudo** is only used for system packages (`prereqs`, CLI utilities, Docker).
  On a rootless box without `sudo`, those installs are skipped with a warning;
  the user-space tools still install fine.
- **Debian/Ubuntu quirks**: `fd`/`bat` ship as `fdfind`/`batcat`; the shell
  block aliases them back to `fd`/`bat` automatically.
- **Runtimes shadow, never replace.** node/python/go from another source (system
  package, `nvm`, `asdf`) are left alone; mise installs its own and wins on PATH.
  Verify with `which -a node`.
- **Docker** is opt-in (confirm-gated): the official `get.docker.com` script
  installs docker-ce + compose + buildx and adds you to the `docker` group
  (effective after re-login).

## First run

After the version checks pass, use a **new, empty practice folder**, not your home
directory, the kit checkout, or an existing project. This command launches Codex
only if creating the folder succeeds. If the name exists, choose another name:

```sh
mkdir "$HOME/my-first-ai" && cd "$HOME/my-first-ai" && git init && codex
```

Replace `codex` with `claude` for Claude Code. Complete the provider's login
yourself. Review any shell-safety hook approval request. Then copy, review, and
manually submit a first request:

> Create a single-file breakout game named index.html in this practice folder that I can open directly in a browser. Don't overwrite or delete existing files. If index.html already exists, stop and ask for another name. Explain how to open the finished file.

Review proposed changes and commands before accepting them, then open the new
file in your browser. There is no native Linux GUI. The v0.14.0 macOS/Windows
GUIs offer a separate Install and Preview, explicit practice-folder launch, and
prompt copy to the clipboard, not automatic login or submission. Optional
`gh auth login`, shell customization, and Docker group changes apply only if you
installed those tools. None is required for the first AI session.

## Automatic uninstall is not supported

v0.14.0 keeps the no-uninstall policy introduced in v0.13.0. There is no removal
UI. The legacy
`linux/uninstall.sh` entrypoint stops with an explanation and exit code 2,
without changing or removing anything. The kit can't reliably distinguish tools
it installed from tools you already had. For individual removals, follow the
tool's official instructions and review your shell configuration manually.

## Troubleshooting

For the default AI setup, start with `./install.sh --profile ai --doctor` and
rerun the same profile after fixing the reported blocker. A required tool skipped
because of permissions still needs attention. The fd/bat, Python, Docker, and gh
notes below apply only to the broader developer profiles.

- **No `sudo` / not root**: system packages (build tools, CLI utils, Docker) are
  skipped with a warning, but the per-user tools (mise, starship, uv, bun, rustup)
  still install fine into `$HOME`.
- **`fd` / `bat` "command not found"**: on Debian/Ubuntu they're `fdfind`/`batcat`;
  the shell block aliases them back once you open a new shell.
- **Python install slow or failing**: the kit forces mise's **precompiled** Python
  (`MISE_PYTHON_COMPILE=0`), so no source build. If your CPU/arch has no prebuilt
  release, install dev headers (`build-essential libssl-dev zlib1g-dev libffi-dev`)
  and re-run `--only runtimes`.
- **`docker: permission denied`**: log out/in (or `newgrp docker`) so your new
  `docker` group membership applies.
- **`gh` not found**: a few distros lack it in default repos; the kit adds GitHub's
  apt repo on Debian/Ubuntu. Elsewhere install your distro's `gh`/`github-cli`.
- **Re-run anytime**: every step is idempotent (use `--only <step>` to redo one).

## License

MIT. See [../LICENSE](../LICENSE).
