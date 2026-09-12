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

v0.14.0의 기본 `ai` 구성은 **Git, Node.js LTS/npm, Claude Code, Codex,
안전 훅, 최소 PATH 설정**과 설치에 필요한 선행 도구만 준비합니다.
Python, Go, Rust, Docker, Bun, uv, 셸 꾸미기, 폰트, 선택 CLI 묶음은 제외합니다.

**v0.14.0으로 시작하세요:** 아래 [릴리스 다운로드와 고정된 소스 명령](#recommended-setup)은
더 작은 AI 구성과 GUI 첫 실행 안내를 사용합니다. v0.13.0에도 `recommended`
개발 프로필과 첫 사용 안내는 있었지만, `ai` 기본값과 새 GUI 흐름은 없었습니다.

명시적으로 선택하는 `recommended`는 다음의 더 넓은 개발 도구 구성을 유지합니다:

- CLI: git, gh, jq, ripgrep, fd, fzf, bat, tree, ast-grep, zoxide
- 런타임: Node.js, Python, Go, Rust
- 셸/프롬프트: macOS/Linux의 zsh와 oh-my-zsh, Windows의 PowerShell, starship, Nerd Font
- AI 에이전트: Claude Code (`claude`), Codex (`codex`)

Docker는 제외하며 Windows의 WSL도 설치하지 않습니다. Hermes는 macOS/Linux의
고급 에이전트 구성에서만 별도 선택합니다. 검토한 소스에서
`HERMES=1 ./install.sh --profile recommended`로 실행하며 Linux는
`./linux/install.sh`를 사용합니다. `ai`는 상속된 `HERMES=1`도 의도적으로
무시합니다. Hermes의 네이티브 Windows 설치기는 없습니다.
현재 키트는 지원이 끝난 gajae-code (`gjc`), lazycodex를
설치하지 않으며, 기존 도구나 해당 설정을 삭제하지도 않습니다.

이미 있는 도구는 가능한 한 그대로 두고, 관리하는 설정 파일은 표시된
블록만 수정합니다. 상태 확인은 `--doctor`, 실행 전 확인은 `--dry-run`을
사용하세요.

---

<a id="ai-setup"></a>

## AI 설치 (v0.14.0)

v0.14.0에서 프로필이나 사용자 지정 단계를 선택하지 않은 일반 GUI·CLI 설치의
기본값은 `ai`입니다. 명시적으로 고른 `recommended`, `full`, `minimal`, `work`는
기존 설치 범위를 유지합니다. **`recommended`는 `ai`의 별칭이 아닙니다.**
Docker와 Windows WSL을 제외한 더 넓은 개발 도구 묶음입니다.

| OS | `ai`의 Node.js LTS |
|---|---|
| macOS | Homebrew `node@24`, npm 포함 |
| Linux | mise `node@lts`, npm 포함 |
| Windows | winget `OpenJS.NodeJS.LTS`, npm 포함 |

**Node.js와 npm은 왜 필요한가요?** npm은 Codex를 설치하고, Node.js는
AI 도구의 안전 훅을 설치하고 실행하는 데 사용해요. 처음에는 실행 도구를 직접
고르지 않아도 돼요. 아래에서 사용 중인 OS의 설치 안내를 따라가세요.

<details>
<summary>도구 용어 알아보기: Node.js, npm, Bun, bunx, mise</summary>

| 이름 | 하는 일 |
|---|---|
| Node.js | 자바스크립트로 만든 프로그램을 실행해요. |
| npm | Node.js와 보통 함께 설치되며, 프로젝트에 필요한 패키지나 CLI 도구를 받아요. |
| Bun | 패키지 설치와 자바스크립트·타입스크립트 프로그램 실행을 모두 할 수 있어요. |
| bunx | Bun에 포함된 명령이에요. CLI 도구를 찾아 실행하고, 없으면 내려받기도 해요. |
| mise | Node.js나 Bun 같은 개발 도구의 버전을 설치하고 선택해요. |

**설치와 실행은 달라요.** npm으로 받는 많은 패키지를 Bun으로도 설치할 수
있지만, 추가 설치 설정이 필요하거나 실행할 때 Node.js가 필요한 도구도 있어요.
Bun으로 설치했다고 모든 프로그램이 Node.js 없이 실행되는 것은 아니에요.

**이름이 나온 도구를 모두 설치하는 것은 아니에요.** 현재 기본 `ai` 구성은
Bun/bunx를 설치하지 않아요. Linux에서는 Node.js 설치에 mise를 사용하지만,
macOS와 Windows의 기본 `ai` 구성에는 mise를 설치하지 않아요. 고급 구성의
설치 범위는 다르므로 실행 전 미리보기에서 확인하세요.

더 알아보기: [Bun 패키지 설치](https://bun.com/docs/pm/cli/install) ·
[bunx 실행 방식](https://bun.com/docs/pm/bunx) ·
[mise 버전 선택](https://mise.jdx.dev/getting-started.html).

</details>

**설치 전 확인:** 다운로드와 AI 서비스에는 인터넷 연결이 필요합니다. Claude
Code는 서비스 이용 권한이 있는 Claude 계정 또는 지원되는 API 인증 정보가,
Codex는 이용 권한이 있는 ChatGPT 계정 또는 지원되는 API 인증 정보가 필요합니다.
설치에 구독, 서비스 이용권, 크레딧은 포함되지 않습니다. 제공자의 약관·결제 조건과
조직 정책을 먼저 확인하세요. 새 GUI도 설치 전에 이 요구사항을 보여줍니다.

v0.14.0 GUI는 **설치**가 기본 동작이고, 변경 없는 **미리보기**는 별도 동작입니다.
미리보기 완료나 설치 프로세스의 성공 종료만으로 준비 완료가 되지 않습니다.
Git, Node, npm, Claude Code, Codex가 실제로 실행되고 버전 확인을 통과해야 합니다.
필수 실행 파일 누락이나 확인 실패는 **조치 필요**입니다. 로컬 준비 확인은 로그인이나
실제 제공자 세션을 검사하지 않습니다.

새 Mac에서는 Xcode Command Line Tools와 Homebrew 선행 설치 안내를 따르세요.
Terminal에서 설치를 이어 진행했다면 완료 후 GUI로 돌아와 **설치 결과 확인**을
실행한 다음 연습을 시작하세요. 설치 전 셸이 아닌 **새 Terminal 창**에서 PATH가
적용된 결과를 확인합니다.

CLI 사용자는 [아래 명령](#recommended-setup)으로 **v0.14.0 소스**를 받은 뒤
최상위 폴더에서 설치기와 스크립트를 읽고, 사용 중인 OS의 행만 실행하세요.

| OS | 미리보기 | 설치 | 새 터미널에서 결과 확인 |
|---|---|---|---|
| macOS | `bash ./install.sh --profile ai --dry-run` | `bash ./install.sh --profile ai` | `bash ./install.sh --profile ai --doctor` |
| Linux | `bash ./linux/install.sh --profile ai --dry-run` | `bash ./linux/install.sh --profile ai` | `bash ./linux/install.sh --profile ai --doctor` |
| Windows | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai -DryRun` | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai` | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai -Doctor` |

필수 도구가 빠졌다면 로그에 나온 원인을 해결한 뒤 같은 `ai` 프로필로 다시
실행하세요. 사용자 지정 `--only` / `-Only`나 프로필 없는 `--skip` / `-Skip`은
기존의 더 넓은 개발 단계 범위를 유지합니다. AI 구성만 고치는 지름길이 아닙니다.
알 수 없는 프로필·단계 이름은 유효한 이름 목록과 함께 거부하며, 프로필과
`--only` / `-Only`는 함께 쓸 수 없습니다.

검사를 통과하면 GUI에서 Claude Code 또는 Codex를 고르고 **새 빈 연습 폴더 열기**를
직접 실행하세요. 프롬프트 복사는 요청을 클립보드에 넣을 뿐 전송하지 않습니다.
로그인, 프롬프트 검토와 전송은 직접 합니다. 자동 제거 기능이나 제거 UI는 없습니다.
직접 터미널에서 시작하는 방법은 [첫 프로젝트](#first-project)에 있습니다.

---

<a id="recommended-setup"></a>

## 추천 설치 (v0.14.0)

**처음이라면 macOS에서는 아래 v0.14.0 GUI를 사용하세요. Windows GUI는 실험적으로 제공합니다.**
기본 `ai` 구성은 Docker와 Windows WSL 없이 Claude Code와 Codex를 준비합니다.
v0.14.0은 gajae-code (`gjc`), lazycodex를 설치하거나 기존 도구와 설정을
삭제하지 않으며, 자동 제거 기능도 제공하지 않습니다.

<a id="gui-downloads"></a>

### GUI 다운로드

| OS | v0.14.0 GUI 파일 | 압축을 푼 뒤 열 파일 |
|---|---|---|
| macOS 14+, Apple Silicon 또는 Intel | [lazy-starter-kit-macos-gui.zip](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.14.0/lazy-starter-kit-macos-gui.zip) | `Lazy Starter Kit Installer.app` |
| Windows (실험적 제공) | [lazy-starter-kit-windows-gui.zip](https://github.com/Heoooooon/lazy-starter-kit/releases/download/v0.14.0/lazy-starter-kit-windows-gui.zip) | `Lazy-Starter-Kit-Installer.cmd` |
| Linux | GUI 패키지 없음 | 아래 v0.14.0 소스 명령 또는 [Linux 안내](linux/README.md) 사용 |

**Windows — 실험적 제공:** 자동화 테스트와 설치 패키지 검증을 완료했습니다.
다만 실제 Windows PC에서 더블클릭, 설치 화면, 권한 승인, 설치 완료, 첫 실행까지의
전체 과정을 수동으로 검증하지는 못했습니다.

GUI의 기본 구성은 **ai**, 기본 동작은 **설치**이며 **미리보기** 버튼은 별도입니다.
설치 없이 계획을 확인하고, 준비되면 설치를 선택하세요. 프로필이나 사용자 지정
단계 없는 일반 CLI 설치도 `ai`입니다. AI 계획에는 `docker`와 Windows `wsl`이
없어야 합니다. 미리보기, 설치 실패·취소, 불완전한 준비 확인으로는 첫 실행 기능이
활성화되지 않습니다. 설치와 검사를 마친 뒤
[새 터미널에서 버전 확인과 첫 프로젝트](#first-project)로 이어집니다.
계정 로그인과 첫 프롬프트 전송은 직접 합니다.

[v0.14.0 릴리스 페이지](https://github.com/Heoooooon/lazy-starter-kit/releases/tag/v0.14.0)에서
변경 내역과 전체 파일을 확인하세요. 패키지 GUI는 자신의 릴리스 커밋에 고정되며,
일반 원격 부트스트랩은 기본적으로 최신 릴리스 태그를 선택합니다.
릴리스 ZIP에 `main`의 변경 사항이 자동으로 반영되지는 않습니다.

**v0.13.0**은 무프로필 CLI의 기본값이 full, GUI는 recommended + 미리보기였습니다.
명시적 개발 프로필과 자동 제거 미지원 정책은 v0.14.0에서도 유지되지만,
이전 ZIP에 새 AI 흐름이 추가되지는 않습니다.

이전 **v0.12.0**에는 `recommended`가 없고 GUI는 full + 미리보기로 시작합니다.
gajae-code와 lazycodex 설치 및 이전 자동 제거 동작도 남아 있으므로,
이 안내의 설치 경로로 사용하지 마세요.

### 소스에서 설치 (Linux 또는 터미널 사용자)

아래 명령은 **v0.14.0 태그**를 clone한 뒤 로컬 설치기를 실행합니다.
먼저 [Git](https://git-scm.com/downloads)을 설치하고 새 터미널을 열어 주세요.
Git 없이 시작하려면 [v0.14.0 소스 ZIP](https://github.com/Heoooooon/lazy-starter-kit/archive/refs/tags/v0.14.0.zip)을
받아 압축을 풀고 `lazy-starter-kit-0.14.0` 폴더에서 터미널을 여세요. ZIP을 사용하면
아래 clone과 `cd` 명령은 생략합니다. 기존 작업 폴더가 아닌 새 폴더를 사용하세요.

### 1. 내용을 읽고 미리보기

실행 전에 편집기에서 설치기와 해당 `scripts/` 폴더를 확인하세요. 미리보기는
설치하지 않고 선택한 단계를 보여줍니다. 계획에 `docker`가 없는지, Windows에서는
`wsl`도 없는지 확인하세요.

### macOS

```bash
git clone --branch v0.14.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0
cd lazy-starter-kit-v0.14.0
# install.sh와 scripts/를 읽은 뒤 미리보기:
bash ./install.sh --profile ai --dry-run
```

### Linux

Ubuntu/Debian, Fedora/RHEL, Arch, openSUSE 계열을 지원합니다.

```bash
git clone --branch v0.14.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0
cd lazy-starter-kit-v0.14.0
# linux/install.sh와 linux/scripts/를 읽은 뒤 미리보기:
bash ./linux/install.sh --profile ai --dry-run
```

상세 문서: [linux/README.md](linux/README.md)

### Windows

PowerShell 5.1 이상에서:

```powershell
git clone --branch v0.14.0 --single-branch https://github.com/Heoooooon/lazy-starter-kit.git lazy-starter-kit-v0.14.0
cd lazy-starter-kit-v0.14.0
# windows/install.ps1과 windows/scripts/를 읽은 뒤 미리보기:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai -DryRun
```

`-ExecutionPolicy Bypass`는 이 자식 프로세스에만 적용되며 저장된 PowerShell 정책을
바꾸지 않습니다. 조직 정책으로 차단될 수 있으므로 IT 제한을 우회하려고 정책을
변경하지 마세요. 상세 문서: [windows/README.md](windows/README.md)

### 2. 확인한 구성 적용

같은 소스 폴더에서 **사용 중인 OS의 명령 하나만** 실행하세요.

| OS | 적용 명령 |
|---|---|
| macOS | `bash ./install.sh --profile ai` |
| Linux | `bash ./linux/install.sh --profile ai` |
| Windows | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -Profile ai` |

필요한 시스템 승인 창은 내용을 읽고 승인하세요. macOS에서는 Xcode Command Line
Tools와 Homebrew 준비가 필요할 수 있습니다. 안내에 따라 준비를 마친 뒤 다시
실행하라는 메시지가 나오면 같은 명령을 실행하세요. 경고와 건너뛴 단계를 확인하세요.
설치 프로세스의 성공 종료가 모든 도구의 설치나 로그인 확인을 뜻하지는 않습니다.
[새 터미널을 열고 첫 프로젝트 시작하기](#first-project)로 이어집니다.

---

## 자주 쓰는 옵션

아래의 명시적 개발 프로필 옵션은 v0.14.0에서도 사용할 수 있습니다.
저장소 루트에서 실행하며, Linux에서는 `./install.sh`를 `./linux/install.sh`로 바꾸세요.

```bash
./install.sh --profile recommended --dry-run
./install.sh --profile recommended --doctor
./install.sh --update --profile recommended
./install.sh --only agents
./install.sh --skip docker
./install.sh --profile minimal
./install.sh --profile work
```

Windows에서는 `windows\install.ps1`에 `--dry-run` 대신 `-DryRun`, `--only`
대신 `-Only`처럼 PowerShell 형식을 사용합니다.

| 프로필 | 설치 범위 |
|---|---|
| `ai` (기본값) | Git, Node LTS/npm, Claude Code, Codex, 안전 훅, 최소 PATH와 필요한 선행 도구. v0.14.0부터 일반 무프로필 설치와 GUI 기본값. |
| `recommended` | 기본 도구, 런타임, 셸, Git, Claude Code와 Codex. Docker와 Windows WSL 제외. `ai`의 별칭이 아닙니다. |
| `full` | Docker와 Windows WSL을 포함한 전체 단계. v0.14.0에서는 명시적으로 선택하며, v0.13.0 이전에는 무프로필 CLI 기본값이었습니다. Windows의 설치 확인과 사전 조건은 그대로 적용됩니다. |
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
Windows에서는 **새 PowerShell 창**을 여세요. 기본 `ai` 구성은 다음 명령과
[AI 설치의 프로필 검사](#ai-setup)로 확인합니다.

```bash
git --version
node --version
npm --version
claude --version
codex --version
```

더 넓은 `recommended` 구성은 다음 명령으로 확인합니다.

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
계정 접속 확인은 아닙니다. 실패하면 해당 단계의 로그를 확인하세요. `ai`는 원인을
해결한 뒤 같은 프로필로 다시 실행합니다. 더 넓은 개발 구성은 소스 폴더에서
해당 단계만 다시 실행할 수 있습니다. macOS/Linux의 `--only runtimes`,
`--only agents` 또는 Windows의 `-Only runtimes`, `-Only agents`가 예입니다.
`--only` / `-Only` 명령에는 `--profile` / `-Profile`을 함께 넣지 마세요.

v0.14.0의 doctor 범위는 OS별로 다릅니다:

- **macOS:** 단독 `--doctor`는 저장된 설치 프로필 마커를 읽으며, 인식 가능한
  마커가 없으면 전체 목록을 점검합니다. AI 실행 파일과 안전 훅 검사는
  `--profile ai --doctor`, 기계 판독용 JSON은 `--profile ai --doctor-json`을 사용하세요.
- **Linux:** 단독 `--doctor`의 기본값은 AI 실행 파일 검사입니다.
  `--profile ai --doctor`로 명시해도 같은 범위를 검사합니다.
- **Windows:** 단독 `-Doctor`는 여전히 전체 목록을 점검합니다.
  AI 실행 파일 검사에는 **`-Profile ai -Doctor`**를 반드시 사용하세요.

AI 검사는 필수 명령을 실행할 수 없으면 실패하며, macOS는 안전 설정도 검사합니다.
제공자 로그인 확인은 아닙니다. 명시적 개발 프로필은 v0.13.0의 모든 doctor 실행과
같은 전체 도구·설정 점검을 유지합니다. 설치됨, PATH에 없음, 누락 상태를 보여주며,
recommended, minimal, work에서는 의도적으로 제외한 Docker/Colima 때문에
종료 코드 1이 나올 수 있습니다. 검사를 통과시키려고 이 도구들을 설치할 필요는 없습니다.

### 2. 새 빈 연습 폴더에서 시작

홈 폴더 전체, 키트 저장소, 기존 프로젝트를 작업장으로 쓰지 마세요. macOS/Linux의
아래 명령은 새 폴더 생성에 성공했을 때만 Codex를 실행합니다. 같은 이름이 이미
있다면 다른 이름을 고르세요.

```bash
mkdir "$HOME/my-first-ai" && cd "$HOME/my-first-ai" && git init && codex
```

Windows는 파일 탐색기에서 새 빈 폴더를 만들고 그 위치에서 PowerShell을 연 뒤
`git init`, `codex`를 실행하세요. Claude Code를 쓰려면 `codex` 대신 `claude`를
실행합니다. v0.14.0 GUI에서는 도구를 고른 뒤 새 연습 폴더 열기를 직접 누르세요.
프롬프트 복사 동작으로 첫 요청을 클립보드에 넣을 수 있습니다.

각 도구의 안내에 따라 직접 로그인합니다. 키트 설치로 계정이나 API 크레딧이
제공되지는 않습니다. Codex가 키트의 셸 안전 훅 승인을 요청하면 내용을 검토한
뒤 승인하세요. 다음 요청을 복사하고 검토한 뒤 직접 전송할 수 있습니다.

> 이 연습 폴더에 브라우저에서 바로 열 수 있는 한 파일짜리 벽돌깨기 게임(index.html)을 만들어 줘. 기존 파일은 덮어쓰거나 삭제하지 마. index.html이 이미 있으면 멈추고 다른 이름을 물어봐. 다 만들면 여는 방법도 알려 줘.

제안된 파일 변경과 명령은 수락하기 전에 확인하세요. 파일이 완성되면 브라우저에서
여세요. 로그인과 프롬프트 전송은 자동으로 하지 않습니다.

---

## 자동 제거(Uninstall)는 지원하지 않습니다

**v0.14.0은 자동 uninstall 기능을 제공하지 않습니다.**

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

기존 런타임을 삭제하지 않습니다. `ai`는 macOS에서 Homebrew `node@24`,
Linux에서 mise `node@lts`, Windows에서 winget `OpenJS.NodeJS.LTS`를 사용합니다.
Python은 `ai`에 없습니다. 더 넓은 개발 프로필은 Node/Python/Go에 mise를 계속
사용합니다. 키트가 설치한 런타임이 새 셸의 PATH에서 우선할 수 있습니다.

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

v0.14.0의 `work` 프로필은 Docker와 Windows WSL을 제외하지만 권한 제한을
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

검증 범위: 이식 가능한 PowerShell 검사는 네이티브 Windows E2E가 아니며,
WinForms/DPI나 Windows 콘솔·레지스트리 PATH 동작의 검증을 뜻하지 않습니다.
로컬 준비 확인과 GUI 검사도 제공자 인증이나 프롬프트 전달을 검증하지 않습니다.

---

## 라이선스

MIT. [LICENSE](LICENSE)
