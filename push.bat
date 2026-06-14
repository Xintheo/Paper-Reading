@echo off
chcp 65001 >nul 2>nul
setlocal EnableDelayedExpansion
echo ============================================================
echo   Paper-Reading Push Tool
echo ============================================================
echo.
set "REPO_DIR=%~dp0"
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: git not found
    pause
    exit /b 1
)
cd /d "%REPO_DIR%"
if not exist ".git" (
    echo ERROR: not a git repo here: %REPO_DIR%
    pause
    exit /b 1
)

echo [1] Changes:
echo ------------------------------------------------------------
git status --short
echo.

for /f %%i in ('git status --short ^| find /c /v ""') do set "CHANGE_COUNT=%%i"

REM --- how many commits are committed locally but not yet on origin/main ---
set "AHEAD=0"
for /f %%a in ('git rev-list --count origin/main..HEAD 2^>nul') do set "AHEAD=%%a"
if not defined AHEAD set "AHEAD=0"

if "%CHANGE_COUNT%"=="0" (
    if "!AHEAD!"=="0" (
        echo   Nothing to commit, nothing to push.
        pause
        exit /b 0
    )
    echo   No new changes, but !AHEAD! commit^(s^) not pushed yet. Going to push...
    echo.
    goto :push
)

echo   Found %CHANGE_COUNT% changes
echo.
echo [2] Commit message (Enter for default):
set "COMMIT_MSG="
set /p "COMMIT_MSG=  > "
if "!COMMIT_MSG!"=="" set "COMMIT_MSG=update"
echo.

echo [3] Updating version.json...
if exist "version.json" (
    powershell -NoProfile -Command ^
        "$f = 'version.json';" ^
        "$j = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json;" ^
        "$v = $j.version -split '\.';" ^
        "$v[2] = [string]([int]$v[2] + 1);" ^
        "$j.version = $v -join '.';" ^
        "$j.updated = Get-Date -Format 'yyyy-MM-dd';" ^
        "$utf8NoBom = New-Object System.Text.UTF8Encoding $false;" ^
        "$text = $j | ConvertTo-Json;" ^
        "[System.IO.File]::WriteAllText((Resolve-Path $f).Path, $text, $utf8NoBom);" ^
        "Write-Host ('  version: ' + $j.version)"
) else (
    echo   version.json not found, skip
)
echo.

echo [4] Committing...
git add -A
git commit -m "!COMMIT_MSG!"
echo.

:push
echo [5] Pushing...
git push origin main
if %errorlevel% neq 0 (
    echo   First push failed, retry with -u ...
    git push -u origin main
)
if %errorlevel% neq 0 (
    echo.
    echo ============================================================
    echo   PUSH FAILED -- read the error above.
    echo   Your commits are safe locally. Fix the cause, then just
    echo   run this tool again; it will re-push the pending commits.
    echo ============================================================
    pause
    exit /b 1
)
echo.
echo ============================================================
echo   Done! Pushed successfully.
echo ============================================================
pause
