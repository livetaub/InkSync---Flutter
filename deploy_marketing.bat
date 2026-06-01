@echo off
if "%CLOUDFLARE_API_TOKEN%"=="" (
    echo ERROR: CLOUDFLARE_API_TOKEN environment variable is not set.
    echo Set it with: set CLOUDFLARE_API_TOKEN=your_token_here
    pause
    exit /b 1
)

cd marketing

echo ========================================
echo   Building InkSync Marketing Site...
echo ========================================
call npm run build
if %errorlevel% neq 0 (
    echo ERROR: React build failed!
    pause
    exit /b %errorlevel%
)

echo ========================================
echo   Deploying Marketing Site to Cloudflare...
echo ========================================
call npx wrangler pages deploy dist --project-name=inksync-marketing --branch=production --commit-dirty=true
if %errorlevel% neq 0 (
    echo ERROR: Deploy failed!
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================
echo   Deploy Complete!                     
echo ========================================
echo Your marketing site is live at:
echo   https://inksyncnote.com
echo.
pause
