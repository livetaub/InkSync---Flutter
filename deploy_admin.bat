@echo off
setlocal enabledelayedexpansion

REM Workaround: VPN/corporate proxy intercepts SSL certs, breaking wrangler API calls
set "NODE_TLS_REJECT_UNAUTHORIZED=0"

REM Load environment variables from .env file (located in the root directory)
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
echo   Building InkSync Admin Portal...
echo ========================================
cd admin_portal
call flutter build web --release
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed!
    cd ..
    pause
    exit /b %errorlevel%
)

echo ========================================
echo   Deploying Admin Portal to Cloudflare Pages...
echo ========================================
call npx wrangler pages deploy build/web --project-name=inksync-admin --branch=main --commit-dirty=true
if %errorlevel% neq 0 (
    echo ERROR: Deploy failed!
    cd ..
    pause
    exit /b %errorlevel%
)

cd ..

echo.
echo ========================================
echo   Deploy Complete!
echo ========================================
echo Your Admin Portal has been deployed.
echo.
pause
