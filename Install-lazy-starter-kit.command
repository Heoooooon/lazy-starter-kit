#!/usr/bin/env bash
set -euo pipefail

INSTALL_URL="${STARTER_KIT_INSTALL_URL:-https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/install.sh}"
PAYLOAD="$(mktemp "${TMPDIR:-/tmp}/lazy-starter-kit-install.XXXXXX")"
trap 'rm -f "$PAYLOAD"' EXIT

pause_before_close() {
  [[ "${STARTER_KIT_NO_PAUSE:-0}" == "1" || ! -t 0 ]] && return
  printf '\n이 창을 닫으려면 Enter 키를 누르세요.'
  read -r _ || true
}

printf '\n'
printf '========================================\n'
printf ' lazy-starter-kit 쉬운 설치\n'
printf '========================================\n\n'
printf '설치 파일을 안전하게 내려받는 중입니다...\n'

if ! curl -fL --retry 3 --connect-timeout 15 "$INSTALL_URL" -o "$PAYLOAD"; then
  printf '\n설치 파일을 내려받지 못했습니다.\n' >&2
  printf '인터넷 연결을 확인한 뒤 이 파일을 다시 더블클릭해 주세요.\n' >&2
  pause_before_close
  exit 1
fi

printf '다운로드 완료. 설치를 시작합니다.\n\n'
set +e
/bin/bash "$PAYLOAD" "$@"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  printf '\n설치가 끝났습니다. 새 터미널을 열면 설정이 적용됩니다.\n'
else
  printf '\n설치가 완료되지 않았습니다. 위 오류를 확인한 뒤 다시 실행해 주세요.\n' >&2
fi
pause_before_close
exit "$status"
