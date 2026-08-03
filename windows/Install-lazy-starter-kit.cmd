@echo off
setlocal
chcp 65001 >nul
title lazy-starter-kit 쉬운 설치

if "%STARTER_KIT_LAUNCHER_SELF_TEST%"=="1" (
  echo launcher-ready
  exit /b 0
)

if not defined STARTER_KIT_INSTALL_URL set "STARTER_KIT_INSTALL_URL=https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/windows/install.ps1"
set "INSTALL_FILE=%TEMP%\lazy-starter-kit-install-%RANDOM%-%RANDOM%.ps1"

echo.
echo ========================================
echo  lazy-starter-kit 쉬운 설치
echo ========================================
echo.
echo 설치 파일을 안전하게 내려받는 중입니다...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $env:STARTER_KIT_INSTALL_URL -OutFile $env:INSTALL_FILE"
if errorlevel 1 (
  echo.
  echo 설치 파일을 내려받지 못했습니다.
  echo 인터넷 연결을 확인한 뒤 이 파일을 다시 더블클릭해 주세요.
  if not "%STARTER_KIT_NO_PAUSE%"=="1" pause
  exit /b 1
)

echo 다운로드 완료. 설치를 시작합니다.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_FILE%" %*
set "INSTALL_EXIT=%ERRORLEVEL%"
del /q "%INSTALL_FILE%" >nul 2>&1

echo.
if "%INSTALL_EXIT%"=="0" (
  echo 설치가 끝났습니다. 새 PowerShell 창을 열면 설정이 적용됩니다.
) else (
  echo 설치가 완료되지 않았습니다. 위 오류를 확인한 뒤 다시 실행해 주세요.
)
if not "%STARTER_KIT_NO_PAUSE%"=="1" pause
exit /b %INSTALL_EXIT%
