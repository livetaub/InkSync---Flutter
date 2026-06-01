@echo off
if "%CLOUDFLARE_API_TOKEN%"=="" (
    echo ERROR: CLOUDFLARE_API_TOKEN environment variable is not set.
    echo Set it with: set CLOUDFLARE_API_TOKEN=your_token_here
    pause
    exit /b 1
)

if "%GEMINI_API_KEY%"=="" (
    echo ERROR: GEMINI_API_KEY environment variable is not set.
    echo Set it with: set GEMINI_API_KEY=your_key_here
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
