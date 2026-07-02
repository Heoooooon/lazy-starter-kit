# 보안 정책 (Security Policy)

lazy-starter-kit를 안전하게 써주셔서 고맙습니다. 취약점을 발견하셨다면
**공개 이슈로 올리기 전에** 아래 방법으로 알려주세요.

## 지원 버전

개인 오픈소스 프로젝트라 지원 범위는 단순합니다.

| 버전 | 지원 |
|---|---|
| `main` (롤링, 1.0 이전) | ✅ 항상 여기서 고칩니다 |
| 최신 릴리스 태그 (`vX.Y.Z`) | ✅ 재현되면 반영 |
| 그 이전 태그 | ❌ (최신으로 올려주세요) |

## 취약점 신고 방법

**GitHub 비공개 취약점 신고**를 권장합니다:
저장소 **Security 탭 → "Report a vulnerability"** 로 비공개 리포트를 열 수 있어요.
(전용 보안 이메일은 따로 없습니다.)

리포트에 아래가 있으면 훨씬 빨리 확인할 수 있어요:

- 어떤 OS에서 (macOS / Linux 배포판 / Windows)
- 어떤 스크립트·단계인지, 재현 방법
- 가능하면 `--dry-run` / `-DryRun` 출력

## 범위 (Scope)

이 키트는 **여러 업스트림 프로젝트의 공식 설치 스크립트를 내려받아 실행**합니다
(Homebrew, oh-my-zsh, `get.docker.com`, Hermes, `npx lazycodex` 등).

- **업스트림 자체의 취약점**(예: Homebrew 설치 스크립트 결함)은 **해당 프로젝트에
  직접** 신고해 주세요 — 우리가 고칠 수 있는 부분이 아닙니다.
- **이 키트의 코드**는 범위 안입니다: 마커 블록(`# >>> lazy-starter-kit ... >>>`)
  편집, 권한(sudo/관리자) 사용, 다운로드 URL·검증 방식, 제거 스크립트 등.
  여기서 문제를 찾으셨다면 꼭 알려주세요.

## 대응 기대치

**최선을 다하지만(best-effort)** 개인 오픈소스 프로젝트라 즉각 대응을 약속드리긴
어렵습니다. 확인되는 대로 `main`에 반영하고 CHANGELOG에 남깁니다. 양해 부탁드려요.

---

# Security Policy (English)

Thanks for helping keep lazy-starter-kit safe. Please report vulnerabilities
**privately, before opening a public issue.**

## Supported versions

| Version | Supported |
|---|---|
| `main` (rolling, pre-1.0) | ✅ fixes land here |
| Latest release tag (`vX.Y.Z`) | ✅ if reproducible |
| Older tags | ❌ (please upgrade) |

## Reporting a vulnerability

Preferred: **GitHub private vulnerability reporting** — go to the repo's
**Security tab → "Report a vulnerability."** There is **no dedicated security
email.** Helpful details: OS (macOS / Linux distro / Windows), which script/step,
repro steps, and `--dry-run` / `-DryRun` output if possible.

## Scope

This kit **downloads and runs official install scripts from upstream projects**
(Homebrew, oh-my-zsh, `get.docker.com`, Hermes, `npx lazycodex`, …).

- **Vulnerabilities in those upstreams** should be reported **to those projects** —
  they're outside our control.
- **Anything in this kit's own code is in scope**: marker-block editing, privilege
  (sudo/admin) use, download URLs and verification, and the uninstall scripts.

## Response expectations

Best-effort only — this is a personal open-source project, so we can't promise an
SLA. Confirmed issues are fixed on `main` and noted in the CHANGELOG. Thanks for
your patience.
