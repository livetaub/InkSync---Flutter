@echo off
setlocal enabledelayedexpansion

REM Workaround: VPN/corporate proxy intercepts SSL certs, breaking wrangler API calls
set "NODE_TLS_REJECT_UNAUTHORIZED=0"

REM Load environment variables from .env file
if exist "%~dp0.env" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0.env") do (
        set "firstchar=%%a"
        set "firstchar=!firstchar:~0,1!"
        if not "!firstchar!"=="#" if not "%%a"=="" set "%%a=%%b"
    )
)

if "!CLOUDFLARE_API_TOKEN!"=="" (
    echo ERROR: CLOUDFLARE_API_TOKEN not found.
    echo Create a .env file from .env.example: copy .env.example .env
    pause
    exit /b 1
)

echo ========================================
echo   Building InkSync Flutter App...
echo ========================================
call flutter build web --release
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b %errorlevel%
)

echo ========================================
echo   Deploying App to Cloudflare Pages...
echo ========================================
call npx wrangler pages deploy build/web --project-name=inksync --commit-dirty=true
if %errorlevel% neq 0 (
    echo ERROR: Deploy failed!
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================
echo   Deploy Complete!
echo ========================================
echo Your app is live at:
echo   https://app.inksyncnote.com
echo.
pause
