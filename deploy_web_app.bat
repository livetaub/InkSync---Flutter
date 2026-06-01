@echo off
REM Load environment variables from .env file
if exist "%~dp0.env" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%~dp0.env") do (
        set "line=%%a"
        if not "!line:~0,1!"=="#" if not "%%a"=="" set "%%a=%%b"
    )
)
setlocal enabledelayedexpansion
if exist "%~dp0.env" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%~dp0.env") do (
        set "line=%%a"
        if not "!line:~0,1!"=="#" if not "%%a"=="" set "%%a=%%b"
    )
)

if "%CLOUDFLARE_API_TOKEN%"=="" (
    echo ERROR: CLOUDFLARE_API_TOKEN not found.
    echo Create a .env file from .env.example: copy .env.example .env
    pause
    exit /b 1
)

if "%GEMINI_API_KEY%"=="" (
    echo ERROR: GEMINI_API_KEY not found.
    echo Create a .env file from .env.example: copy .env.example .env
    pause
    exit /b 1
)

echo ========================================
echo   Building InkSync Flutter App...
echo ========================================
call flutter build web --release --dart-define=GEMINI_API_KEY=%GEMINI_API_KEY%
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
