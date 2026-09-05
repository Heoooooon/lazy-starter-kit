<div align="center">

### Set up a Linux development environment with a preview first.

_Build tools · CLI · runtimes · shell · Git · Codex and Claude Code. Containers are optional._

**[← Back to repo root](../README.md)** · [macOS kit](../README.md) · [Windows kit](../windows/README.md)

</div>

---

> **🇰🇷 한국어 빠른 시작**: Git이 설치된 터미널에서 `main` 소스를 새 폴더에
> 복제하고 추천 구성을 미리 확인하세요. `lazy-starter-kit-source` 폴더가 이미
> 있다면 다른 작업 폴더에서 시작하세요. 복제에 실패하면 다음 단계로 진행하지 마세요.
> ```sh
> git clone --branch main --depth 1 https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-source &&
>   cd lazy-starter-kit-source/linux &&
>   ./install.sh --profile recommended --dry-run
> ```
> 로그를 확인한 뒤 같은 터미널에서 아래 명령을 실행하면 Docker 없이 설치합니다:
> ```sh
> ./install.sh --profile recommended
> ```
> apt·dnf·pacman·zypper를 자동 감지합니다 (glibc 배포판; Alpine/musl 미지원).
> [한국어 추천 설치 안내](../README.md#recommended-setup)

## Quick start

With Git available, clone `main` into a fresh directory and preview the
recommended profile. This uses source, not the latest release (`v0.12.0`).
Start in a folder without an existing `lazy-starter-kit-source` directory.
The `&&` chain stops if cloning or changing directories fails:

```sh
git clone --branch main --depth 1 https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-source &&
  cd lazy-starter-kit-source/linux &&
  ./install.sh --profile recommended --dry-run
```

After reviewing the preview, apply from the same terminal and directory:

```sh
./install.sh --profile recommended # apply without Docker
```

`recommended` selects `prereqs,packages,runtimes,shell,git,agents`.
The CLI default is still `full` when no profile is specified. `minimal` also
omits agents; `work` selects the same steps as `recommended`.

**Supported distros** (auto-detected package manager): Debian/Ubuntu (`apt`),
Fedora/RHEL (`dnf`/`yum`), Arch (`pacman`), openSUSE (`zypper`) — all **glibc**.
Alpine/musl (`apk`) is **not supported** (upstream node, ast-grep and bun ship
no musl builds). CI includes installation and verification jobs for Ubuntu,
Fedora, openSUSE and Arch. It doesn't run automatic uninstall.

## What you get

| Layer | Tools |
|---|---|
| **Base** | compiler/build tools, `git`, `curl`, `wget`, `unzip`, `zsh` (via your distro's package manager) |
| **CLI** | ripgrep, fd, bat, fzf, jq, tree, **gh** (GitHub CLI), zoxide |
| **Shell** | zsh + oh-my-zsh (plugins: git, npm, node, autosuggestions, syntax-highlighting), **starship** prompt |
| **Runtimes** | **mise** → node (LTS), python, go, **ast-grep** · **rustup** → rust + rust-analyzer · **uv** · **bun** |
| **Containers** | **Docker Engine** + compose/buildx (official `get.docker.com`, opt-in) |
| **Git/GitHub** | identity (GitHub noreply email), HTTPS credential helper, sane defaults |
| **AI agents** | **Claude Code** (`claude`) and **Codex** (`codex`). **Hermes Agent** (`hermes`) is optional, enabled only with `HERMES=1`. |

After installation, open a new terminal and check `codex --version` and
`claude --version`. Then follow the [first-project guide](../README.en.md#first-project)
and complete the chosen agent's own sign-in flow. An installer exit code alone
doesn't verify every tool or authenticate your accounts.

## Steps & flags

Steps run in this order:

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
./install.sh --doctor              # full inventory, not a profile-specific check
./install.sh --update              # pull the latest kit, then re-run
./install.sh --profile recommended # no Docker; full remains the CLI default
./install.sh --profile work        # corporate PCs; same steps as recommended
```

Doctor checks its full tool/config inventory regardless of the selected profile.
Tools you intentionally skipped can be reported missing; don't install them just
to make the report green. Use explicit version checks for the tools you selected.

Every step is **idempotent** — safe to re-run. `${ZDOTDIR-$HOME}/.zshrc` is edited via clearly
marked managed blocks (`# >>> lazy-starter-kit:* >>>`) that get replaced (never
duplicated) on re-runs. Existing files you own are preserved.

The agents step also installs a Codex/Claude Code `PreToolUse` guard that blocks
recursive `rm` and provides `lazy-safe-rm` for strict descendants of the current
Git workspace. Recursive installer cleanup independently validates
physical containment and refuses root, HOME, boundary, outside, and symlink targets.

## Design notes

- **No Homebrew.** Plain CLI utilities come from your distro's package manager;
  the "moving target" developer tools (mise, starship, uv, bun, rustup) are
  installed from their **official user-space installers** into `$HOME`, so the
  kit works the same across every distro and needs **no root** for them.
- **sudo** is only used for system packages (`prereqs`, CLI utilities, Docker).
  On a rootless box without `sudo`, those installs are skipped with a warning;
  the user-space tools still install fine.
- **Debian/Ubuntu quirks**: `fd`/`bat` ship as `fdfind`/`batcat` — the shell
  block aliases them back to `fd`/`bat` automatically.
- **Runtimes shadow, never replace.** node/python/go from another source (system
  package, `nvm`, `asdf`) are left alone; mise installs its own and wins on PATH.
  Verify with `which -a node`.
- **Docker** is opt-in (confirm-gated): the official `get.docker.com` script
  installs docker-ce + compose + buildx and adds you to the `docker` group
  (effective after re-login).

## Automatic uninstall is not supported

The current source doesn't provide automatic uninstall. The legacy
`linux/uninstall.sh` entrypoint stops with an explanation and exit code 2,
without changing or removing anything. The kit can't reliably distinguish tools
it installed from tools you already had. For individual removals, follow the
tool's official instructions and review your shell configuration manually.

## Troubleshooting

- **No `sudo` / not root** — system packages (build tools, CLI utils, Docker) are
  skipped with a warning, but the per-user tools (mise, starship, uv, bun, rustup)
  still install fine into `$HOME`.
- **`fd` / `bat` "command not found"** — on Debian/Ubuntu they're `fdfind`/`batcat`;
  the shell block aliases them back once you open a new shell.
- **Python install slow or failing** — the kit forces mise's **precompiled** Python
  (`MISE_PYTHON_COMPILE=0`), so no source build. If your CPU/arch has no prebuilt
  release, install dev headers (`build-essential libssl-dev zlib1g-dev libffi-dev`)
  and re-run `--only runtimes`.
- **`docker: permission denied`** — log out/in (or `newgrp docker`) so your new
  `docker` group membership applies.
- **`gh` not found** — a few distros lack it in default repos; the kit adds GitHub's
  apt repo on Debian/Ubuntu. Elsewhere install your distro's `gh`/`github-cli`.
- **Re-run anytime** — every step is idempotent (use `--only <step>` to redo one).

## License

MIT — see [../LICENSE](../LICENSE).
