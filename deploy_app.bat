@echo off
set CLOUDFLARE_API_TOKEN=pfCc3cr0JV4X6O22nmePelHEGqAcM7rU39LYxnZo
set NODE_TLS_REJECT_UNAUTHORIZED=0

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
