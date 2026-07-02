<!-- 고맙습니다! 아래를 간단히 채워주세요. (Thanks! Please fill this in briefly.) -->

## 무엇을 / 왜 (What & why)

<!-- 바뀐 내용과 이유를 한두 줄로 -->

## 어떤 OS 트리를 건드렸나요? (Which OS trees?)

- [ ] macOS (저장소 최상위 / repo root)
- [ ] `linux/`
- [ ] `windows/`
- [ ] 공통·문서만 (shared / docs only)

> 여러 OS에 걸친 공통 로직이면 **트리 간 동작을 맞췄는지(parity)** 확인해주세요.

## 체크리스트 (Checklist)

- [ ] `shellcheck` + `bash -n`(맥/리눅스) 또는 PowerShell 파싱(윈도우)을 **로컬에서** 돌렸어요
- [ ] `--dry-run` / `-DryRun` 으로 미리보기 확인 — 멱등·비파괴 유지
- [ ] 사용자에게 보이는 변경이면 `VERSION` + `CHANGELOG.md` 업데이트 (필요 시 문서도)
