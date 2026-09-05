<div align="center">

<img src="./docs/images/lsk-hero.svg" alt="lazy-starter-kit. 개발 준비, 바로 시작." width="100%" />

*위 그림은 이전 릴리스의 full 구성 미리보기 예시이며, 현재 추천 구성의 설치나 검증 결과가 아닙니다. [현재 추천 설치](#recommended-setup)를 따라 주세요.*

### 사람마다 다른 출발선을 한 줄로 맞춥니다.

AI 코딩, 내 컴퓨터에서 시작하는 가장 빠른 길.

[![CI](https://github.com/Heoooooon/lazy-starter-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/Heoooooon/lazy-starter-kit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/Heoooooon/lazy-starter-kit?label=release&sort=semver&color=2ea043)](https://github.com/Heoooooon/lazy-starter-kit/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/OS-macOS%20·%20Linux%20·%20Windows-000000)](#)

**한국어** · [English](./README.en.md) · [추천 설치](#recommended-setup) · [첫 프로젝트](#first-project) · [변경 이력](./CHANGELOG.md)

</div>

---

## 이게 뭔가요?

새 노트북이나 PC에서 개발을 시작하려면 Git, 런타임, 터미널 도구, Docker,
AI 코딩 에이전트 등을 하나씩 설치해야 합니다.

lazy-starter-kit은 이 과정을 한 번에 구성하고, 설치가 끝난 뒤 제대로
동작하는지 확인할 수 있게 만든 개발 환경 부트스트랩입니다.

v0.13.0의 추천 설치에 포함되는 항목:

- CLI: git, gh, jq, ripgrep, fd, fzf, bat, tree, ast-grep, zoxide
- 런타임: Node.js, Python, Go, Rust
- 셸/프롬프트: macOS/Linux의 zsh와 oh-my-zsh, Windows의 PowerShell, starship, Nerd Font
- AI 에이전트: Claude Code (`claude`), Codex (`codex`)

Docker는 제외하며 Windows의 WSL도 설치하지 않습니다. Hermes는 macOS/Linux에서
`HERMES=1`로 별도 선택하는 도구이며 추천 구성에는 포함되지 않습니다. 네이티브
Windows 설치기는 없습니다. 현재 키트는 지원이 끝난 gajae-code (`gjc`), lazycodex를
설치하지 않으며, 기존 도구나 해당 설정을 삭제하지도 않습니다.

이미 있는 도구는 가능한 한 그대로 두고, 관리하는 설정 파일은 표시된
블록만 수정합니다. 상태 확인은 `--doctor`, 실행 전 확인은 `--dry-run`을
사용하세요.

---

<a id="recommended-setup"></a>

## 추천 설치 (v0.13.0)

**처음이라면 macOS와 Windows에서는 아래 v0.13.0 GUI를 사용하세요.**
추천 구성은 Docker와 Windows WSL 없이 Claude Code와 Codex를 준비합니다.
v0.13.0은 gajae-code (`gjc`), lazycodex를 설치하거나 기존 도구와 설정을
삭제하지 않으며, 자동 제거 기능도 제공하지 않습니다.

<a id="gui-downloads"></a>

### GUI 다운로드

| OS | v0.13.0 GUI 파일 | 압축을 푼 뒤 열 파일 |
|---|---|---|
| macOS 14+, Apple Silicon 또는 Intel | [lazy-starter-kit-macos-gui.zip](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.13.0/lazy-starter-kit-macos-gui.zip) | `Lazy Starter Kit Installer.app` |
| Windows | [lazy-starter-kit-windows-gui.zip](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.13.0/lazy-starter-kit-windows-gui.zip) | `Lazy-Starter-Kit-Installer.cmd` |
| Linux | GUI 패키지 없음 | 아래 v0.13.0 소스 명령 또는 [Linux 안내](linux/README.md) 사용 |

GUI는 **recommended + 미리보기**로 시작합니다. 선택한 구성과 미리보기 로그를
확인한 뒤 미리보기를 끄고 적용하세요. 추천 계획에는 `docker`가 없고 Windows에서는
`wsl`도 없어야 합니다. CLI에서 프로필을 생략하면 여전히 **full**입니다.
설치 후에는 [새 터미널에서 버전 확인과 첫 프로젝트](#first-project)로 이어집니다.
설치 프로세스의 성공 종료만으로 모든 도구의 설치나 로그인이 확인되지는 않습니다.

[v0.13.0 릴리스 페이지](https://github.com/Heoooooon/lazy-starter-kit/releases/tag/v0.13.0)에서
변경 내역과 전체 파일을 확인하세요. 패키지 GUI는 자신의 릴리스 커밋에 고정되며,
일반 원격 부트스트랩은 기본적으로 최신 릴리스 태그를 선택합니다.
릴리스 ZIP에 `main`의 변경 사항이 자동으로 반영되지는 않습니다.

이전 **v0.12.0**에는 `recommended`가 없고 GUI는 full + 미리보기로 시작합니다.
gajae-code와 lazycodex 설치 및 이전 자동 제거 동작도 남아 있으므로,
이 안내의 설치 경로로 사용하지 마세요.

### 소스에서 설치 (Linux 또는 터미널 사용자)

아래 명령은 **v0.13.0 태그**를 clone한 뒤 로컬 설치기를 실행합니다.
먼저 [Git](https://git-scm.com/downloads)을 설치하고 새 터미널을 열어 주세요.
Git 없이 시작하려면 [v0.13.0 소스 ZIP](https://github.com/Heoooooon/lazy-starter-kit/archive/refs/tags/v0.13.0.zip)을
받아 압축을 풀고 `lazy-starter-kit-0.13.0` 폴더에서 터미널을 여세요. ZIP을 사용하면
아래 clone과 `cd` 명령은 생략합니다. 기존 작업 폴더가 아닌 새 폴더를 사용하세요.

### 1. 내용을 읽고 미리보기

실행 전에 편집기에서 설치기와 해당 `scripts/` 폴더를 확인하세요. 미리보기는
설치하지 않고 선택한 단계를 보여줍니다. 계획에 `docker`가 없는지, Windows에서는
`wsl`도 없는지 확인하세요.

### macOS

```bash
git clone --branch v0.13.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.13.0
cd lazy-starter-kit-v0.13.0
# install.sh와 scripts/를 읽은 뒤 미리보기:
bash ./install.sh --profile recommended --dry-run
```

### Linux

Ubuntu/Debian, Fedora/RHEL, Arch, openSUSE 계열을 지원합니다.

```bash
git clone --branch v0.13.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.13.0
cd lazy-starter-kit-v0.13.0
# linux/install.sh와 linux/scripts/를 읽은 뒤 미리보기:
bash ./linux/install.sh --profile recommended --dry-run
```

상세 문서: [linux/README.md](linux/README.md)

### Windows

PowerShell 5.1 이상에서:

```powershell
git clone --branch v0.13.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.13.0
cd lazy-starter-kit-v0.13.0
# windows/install.ps1과 windows/scripts/를 읽은 뒤 미리보기:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile recommended -DryRun
```

`-ExecutionPolicy Bypass`는 이 자식 프로세스에만 적용되며 저장된 PowerShell 정책을
바꾸지 않습니다. 조직 정책으로 차단될 수 있으므로 IT 제한을 우회하려고 정책을
변경하지 마세요. 상세 문서: [windows/README.md](windows/README.md)

### 2. 확인한 구성 적용

같은 소스 폴더에서 **사용 중인 OS의 명령 하나만** 실행하세요.

| OS | 적용 명령 |
|---|---|
| macOS | `bash ./install.sh --profile recommended` |
| Linux | `bash ./linux/install.sh --profile recommended` |
| Windows | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile recommended` |

필요한 시스템 승인 창은 내용을 읽고 승인하세요. macOS에서는 Xcode Command Line
Tools와 Homebrew 준비가 필요할 수 있습니다. 안내에 따라 준비를 마친 뒤 다시
실행하라는 메시지가 나오면 같은 명령을 실행하세요. 경고와 건너뛴 단계를 확인하세요.
설치 프로세스의 성공 종료가 모든 도구의 설치나 로그인 확인을 뜻하지는 않습니다.
[새 터미널을 열고 첫 프로젝트 시작하기](#first-project)로 이어집니다.

---

## 자주 쓰는 옵션

v0.13.0 소스의 저장소 루트에서 실행합니다. Linux에서는 `./install.sh`를
`./linux/install.sh`로 바꾸세요.

```bash
./install.sh --profile recommended --dry-run
./install.sh --doctor
./install.sh --update --profile recommended
./install.sh --only agents
./install.sh --skip docker
./install.sh --profile minimal
./install.sh --profile work
```

Windows에서는 `windows\install.ps1`에 `--dry-run` 대신 `-DryRun`, `--only`
대신 `-Only`처럼 PowerShell 형식을 사용합니다.

| 프로필 | v0.13.0 설치 범위 |
|---|---|
| `recommended` | 기본 도구, 런타임, 셸, Git, Claude Code와 Codex. Docker와 Windows WSL 제외. |
| `full` | Docker와 Windows WSL을 포함한 전체 단계. CLI에서 프로필을 생략하면 여전히 이 범위를 사용합니다. Windows의 설치 확인과 사전 조건은 그대로 적용됩니다. |
| `minimal` | 기본 도구, 런타임, 셸, Git. 에이전트, Docker, Windows WSL 제외. |
| `work` | recommended와 같은 단계. 설치 전 회사 정책을 확인하세요. |

프로필은 `--skip` / `-Skip`과 함께 사용할 수 있지만 `--only` / `-Only`와는
함께 사용할 수 없습니다. `--update` / `-Update`는 Git checkout이 필요하므로
소스 ZIP에서는 사용할 수 없습니다.

설치 단계는 여러 번 실행해도 같은 관리 블록을 중복 생성하지 않도록
멱등성을 기준으로 설계되어 있습니다.

---

<a id="first-project"></a>

## 첫 프로젝트

### 1. 새 터미널에서 버전 확인

설치된 PATH와 셸 설정이 반영되도록 macOS/Linux에서는 **새 터미널 창**,
Windows에서는 **새 PowerShell 창**을 여세요. 추천 구성은 다음 명령으로 확인합니다.

```bash
git --version
node --version
python --version
go version
rustc --version
codex --version
claude --version
```

PowerShell에서도 같은 명령을 사용할 수 있습니다. 명령 실행 여부를 확인하는 것이며
계정 접속 확인은 아닙니다. 실패하면 설치 로그의 해당 단계를 확인한 뒤 소스 폴더에서
그 단계만 다시 실행하세요. macOS/Linux 설치기의 `--only runtimes`, `--only agents`
또는 Windows의 `-Only runtimes`, `-Only agents`가 예입니다.
`--only` / `-Only` 명령에는 `--profile` / `-Profile`을 함께 넣지 마세요.

`--doctor` / `-Doctor`는 선택적으로 실행하는 **전체 도구 목록 점검**이며 프로필별
성공 판정이 아닙니다. 설치됨, PATH에 없음, 누락 상태를 보여줍니다. recommended,
minimal, work 구성에서는 의도적으로 제외한 Docker/Colima가 누락으로 표시되어
종료 코드 1이 나올 수 있습니다. doctor를 통과시키려고 이 도구들을 설치할 필요는 없습니다.

### 2. 프로젝트 폴더에서 시작

프로젝트를 보관할 위치에서 아직 사용하지 않은 폴더 이름을 고르세요.

```bash
mkdir my-first-project
cd my-first-project
git init
codex
```

Claude Code를 쓰려면 마지막에 `claude`를 실행하세요. 각 도구의 안내에 따라
로그인합니다. 키트 설치로 계정이나 API 크레딧이 제공되지는 않습니다.
Codex가 키트의 셸 안전 훅 승인을 요청하면 내용을 검토한 뒤 승인하세요.
첫 요청은 "간단한 hello-world 페이지를 만들고 실행 방법을 설명해 줘"처럼
시작할 수 있습니다. 제안된 파일 변경과 명령은 수락하기 전에 확인하세요.

---

## 자동 제거(Uninstall)는 지원하지 않습니다

**v0.13.0은 자동 uninstall 기능을 제공하지 않습니다.**

이전 v0.12.0에는 당시의 제거 동작이 남아 있습니다. 기존 컴퓨터를 정리하려고
오래된 릴리스의 제거 스크립트를 사용하지 마세요.

이전 버전에는 제거 스크립트가 있었지만 폐기했습니다. 이유는 설치 이후
시점만 보고는 어떤 도구가 lazy-starter-kit이 새로 설치한 것인지, 사용자가
원래 사용하던 것인지 신뢰성 있게 구분할 수 없기 때문입니다.

예를 들어 사용자가 이미 Codex, Claude Code, Homebrew 패키지, mise,
oh-my-zsh 등을 사용하고 있었다면 이름이나 경로만 기준으로 자동 삭제하는
방식은 기존 개발 환경이나 사용자 데이터를 지울 위험이 있습니다.

따라서 현재 정책은 다음과 같습니다.

- 자동으로 패키지나 개발 도구를 제거하지 않습니다.
- 기존 `uninstall.sh`, `linux/uninstall.sh`, `windows/uninstall.ps1` 진입점은
  삭제 작업을 수행하지 않고 중단합니다.
- 특정 도구를 제거해야 한다면 해당 도구의 공식 제거 방법을 사용하세요.
- `.zshrc`, `.zprofile`, PowerShell profile의
  `lazy-starter-kit` 표시 블록은 내용을 확인한 뒤 수동으로 제거하세요.

향후 설치 시점의 소유권을 신뢰성 있게 기록하는 방식이 마련되기 전까지
자동 제거 기능은 다시 추가하지 않습니다.

---

## 안전 설계

- **Dry run**: 적용 전에 실행 계획을 확인할 수 있습니다.
- **기존 설정 보호**: 사용자 설정 전체를 교체하지 않고 관리 블록을 사용합니다.
- **손상된 마커 fail-closed**: 관리 블록 마커가 비정상이면 파일 수정을 거부합니다.
- **설정 백업**: 관리 파일을 처음 변경할 때 `.bak` 백업을 만듭니다.
- **재귀 삭제 경계 검사**: 내부 정리가 필요한 경우 HOME/루트/경계 밖/심볼릭 링크를 거부합니다.
- **AI shell guard**: Codex/Claude Code의 재귀 `rm` 호출을 차단하는 추가 방어층을 제공합니다.
- **소스와 릴리스 구분**: 로컬 checkout은 해당 소스를 실행합니다. 일반 원격 부트스트랩은 최신 릴리스 태그를, 릴리스 GUI는 자신의 커밋을 사용합니다.
- **CI**: macOS, Windows, Ubuntu, Fedora, Arch, openSUSE에서 설치와 상태 검증을 자동 실행합니다.

이 키트는 Homebrew, npm/bun 패키지, 각 프로젝트의 공식 설치 프로그램 등
여러 외부 공급망을 신뢰합니다. 자세한 범위는 [SECURITY.md](SECURITY.md)를
참고하세요.

---

## 이미 Node/Python이 설치되어 있다면

기존 런타임을 삭제하지 않습니다. Node/Python/Go는 mise가 별도 버전을
설치하고 새 셸에서 우선 사용하도록 구성할 수 있습니다.

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

## 회사 PC

v0.13.0의 `work` 프로필은 Docker와 Windows WSL을 제외하지만 권한 제한을
우회하지는 않습니다. 소스 루트에서 실행하세요. Linux는 `./linux/install.sh`를 사용합니다.

```bash
./install.sh --profile work
```

Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile work
```

관리자 권한이나 사내 정책 때문에 설치할 수 없는 항목은 건너뛰거나 안내를
출력합니다. AppLocker, MDM, 프록시 등 조직 정책으로 실행 자체가 차단된
환경에서는 IT 관리자 정책을 따라야 합니다.

---

## 개발 / 기여

- 설계: [DESIGN.md](DESIGN.md)
- 버전 정책: [VERSIONING.md](VERSIONING.md)
- 보안 정책: [SECURITY.md](SECURITY.md)
- 기여 가이드: [CONTRIBUTING.md](CONTRIBUTING.md)
- 변경 이력: [CHANGELOG.md](CHANGELOG.md)

```bash
./install.sh --dry-run
./install.sh --doctor
```

CI는 셸 문법, shellcheck/PSScriptAnalyzer, 설치, 멱등성, doctor,
업그레이드 경로와 주요 안전 회귀 테스트를 확인합니다.

---

## 라이선스

MIT. [LICENSE](LICENSE)
