@echo off
set CLOUDFLARE_API_TOKEN=pfCc3cr0JV4X6O22nmePelHEGqAcM7rU39LYxnZo
set NODE_TLS_REJECT_UNAUTHORIZED=0

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
