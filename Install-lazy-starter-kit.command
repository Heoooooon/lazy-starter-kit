#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLED_PAYLOAD="$SCRIPT_DIR/install.sh"
BUNDLED_VERSION="$SCRIPT_DIR/VERSION"
BUNDLED_COMMIT="$SCRIPT_DIR/RELEASE_COMMIT"
EXPECTED_SHA256="__BOOTSTRAP_SHA256__"
PAYLOAD=""
CLEANUP_PAYLOAD=0
# shellcheck disable=SC2329 # invoked by the EXIT trap below
cleanup() {
  if [[ "$CLEANUP_PAYLOAD" == "1" && -n "$PAYLOAD" ]]; then
    rm -f "$PAYLOAD"
  fi
}
trap cleanup EXIT

pause_before_close() {
  [[ "${STARTER_KIT_NO_PAUSE:-0}" == "1" || ! -t 0 ]] && return
  printf '\n이 창을 닫으려면 Enter 키를 누르세요.'
  read -r _ || true
}

printf '\n'
printf '========================================\n'
printf ' lazy-starter-kit 쉬운 설치\n'
printf '========================================\n\n'
if [[ -f "$BUNDLED_PAYLOAD" && -f "$BUNDLED_VERSION" && -f "$BUNDLED_COMMIT" ]]; then
  PAYLOAD="$BUNDLED_PAYLOAD"
  release_version="$(<"$BUNDLED_VERSION")"
  release_commit="$(<"$BUNDLED_COMMIT")"
  temporary_root="${TMPDIR:-/tmp}"
  temporary_root="${temporary_root%/}"
  export STARTER_KIT_REPO="https://github.com/Heoooooon/lazy-starter-kit.git"
  export STARTER_KIT_DIR="$temporary_root/lazy-starter-kit-$RANDOM-$RANDOM"
  export STARTER_KIT_EPHEMERAL_ROOT="$STARTER_KIT_DIR"
  export STARTER_KIT_BRANCH="v$release_version"
  export STARTER_KIT_COMMIT="$release_commit"
  printf '포함된 설치 파일의 무결성을 확인하는 중입니다...\n'
else
  if [[ "${STARTER_KIT_LAUNCHER_DEVELOPER_MODE:-0}" != "1" ]]; then
    printf '릴리스 ZIP을 모두 압축 해제한 뒤 다시 실행해 주세요.\n' >&2
    exit 1
  fi
  INSTALL_URL="${STARTER_KIT_INSTALL_URL:-}"
  EXPECTED_SHA256="${STARTER_KIT_INSTALL_SHA256:-}"
  if [[ -z "$INSTALL_URL" || -z "$EXPECTED_SHA256" ]]; then
    printf '이 파일만으로는 설치할 수 없습니다. 릴리스 ZIP을 모두 압축 해제해 주세요.\n' >&2
    exit 1
  fi
  PAYLOAD="$(mktemp "${TMPDIR:-/tmp}/lazy-starter-kit-install.XXXXXX")"
  CLEANUP_PAYLOAD=1
  printf '설치 파일을 안전하게 내려받는 중입니다...\n'
  if ! curl -fL --retry 3 --connect-timeout 15 "$INSTALL_URL" -o "$PAYLOAD"; then
    printf '\n설치 파일을 내려받지 못했습니다.\n' >&2
    printf '인터넷 연결을 확인한 뒤 이 파일을 다시 더블클릭해 주세요.\n' >&2
    pause_before_close
    exit 1
  fi
fi

if [[ ! "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  printf '설치 파일 검증 정보가 올바르지 않습니다.\n' >&2
  exit 1
fi
actual_sha256="$(shasum -a 256 "$PAYLOAD" | awk '{print $1}')"
if [[ "$actual_sha256" != "$EXPECTED_SHA256" ]]; then
  printf '설치 파일의 무결성 확인에 실패했습니다.\n' >&2
  exit 1
fi

printf '설치 파일 확인 완료. 설치를 시작합니다.\n\n'
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
