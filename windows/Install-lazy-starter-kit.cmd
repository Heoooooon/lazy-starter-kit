@echo off
setlocal
chcp 65001 >nul
title lazy-starter-kit 쉬운 설치

if "%STARTER_KIT_LAUNCHER_SELF_TEST%"=="1" (
  echo launcher-ready
  exit /b 0
)

set "BUNDLED_INSTALLER=%~dp0bootstrap-install.ps1"
set "BUNDLED_VERSION=%~dp0VERSION"
set "BUNDLED_COMMIT=%~dp0RELEASE_COMMIT"
set "EXPECTED_SHA256=__BOOTSTRAP_SHA256__"
set "DELETE_INSTALL_FILE=0"

if not exist "%BUNDLED_INSTALLER%" goto override_source
if not exist "%BUNDLED_VERSION%" goto override_source
if not exist "%BUNDLED_COMMIT%" goto override_source
set "INSTALL_FILE=%BUNDLED_INSTALLER%"
set "STARTER_KIT_REPO=https://github.com/Heoooooon/lazy-starter-kit.git"
set "STARTER_KIT_DIR=%TEMP%\lazy-starter-kit-%RANDOM%-%RANDOM%"
set "STARTER_KIT_EPHEMERAL_ROOT=%STARTER_KIT_DIR%"
for /f "usebackq delims=" %%V in ("%BUNDLED_VERSION%") do set "STARTER_KIT_BRANCH=v%%V"
for /f "usebackq delims=" %%C in ("%BUNDLED_COMMIT%") do set "STARTER_KIT_COMMIT=%%C"
goto source_ready

:override_source
if not "%STARTER_KIT_LAUNCHER_DEVELOPER_MODE%"=="1" goto incomplete_package
if not defined STARTER_KIT_INSTALL_URL goto incomplete_package
if not defined STARTER_KIT_INSTALL_SHA256 goto incomplete_package
set "EXPECTED_SHA256=%STARTER_KIT_INSTALL_SHA256%"
set "INSTALL_FILE=%TEMP%\lazy-starter-kit-install-%RANDOM%-%RANDOM%.ps1"
set "DELETE_INSTALL_FILE=1"

:source_ready

echo.
echo ========================================
echo  lazy-starter-kit 쉬운 설치
echo ========================================
echo.
echo 설치 파일을 확인하는 중입니다...

if "%DELETE_INSTALL_FILE%"=="1" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $env:STARTER_KIT_INSTALL_URL -OutFile $env:INSTALL_FILE"
  if errorlevel 1 (
    echo.
    echo 설치 파일을 내려받지 못했습니다.
    echo 인터넷 연결을 확인한 뒤 이 파일을 다시 더블클릭해 주세요.
    if not "%STARTER_KIT_NO_PAUSE%"=="1" pause
    exit /b 1
  )
)

powershell.exe -NoProfile -Command ^
  "$actual=(Get-FileHash -LiteralPath $env:INSTALL_FILE -Algorithm SHA256).Hash.ToLowerInvariant(); if ($env:EXPECTED_SHA256 -notmatch '^[0-9a-f]{64}$' -or $actual -ne $env:EXPECTED_SHA256) { exit 1 }"
if errorlevel 1 (
  echo 설치 파일의 무결성 확인에 실패했습니다.
  if "%DELETE_INSTALL_FILE%"=="1" del /q "%INSTALL_FILE%" >nul 2>&1
  exit /b 1
)

echo 설치 파일 확인 완료. 설치를 시작합니다.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_FILE%" %*
set "INSTALL_EXIT=%ERRORLEVEL%"
if "%DELETE_INSTALL_FILE%"=="1" del /q "%INSTALL_FILE%" >nul 2>&1

echo.
if "%INSTALL_EXIT%"=="0" (
  echo 설치가 끝났습니다. 새 PowerShell 창을 열면 설정이 적용됩니다.
) else (
  echo 설치가 완료되지 않았습니다. 위 오류를 확인한 뒤 다시 실행해 주세요.
)
if not "%STARTER_KIT_NO_PAUSE%"=="1" pause
exit /b %INSTALL_EXIT%

:incomplete_package
echo 릴리스 ZIP을 모두 압축 해제한 뒤 다시 실행해 주세요.
if not "%STARTER_KIT_NO_PAUSE%"=="1" pause
exit /b 1
