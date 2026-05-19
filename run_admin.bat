@echo off
echo ===================================================
echo Starting InkSync Admin Portal Development Server...
echo ===================================================
cd admin_portal
call flutter run -d chrome --web-port=51199 --web-hostname=localhost
pause
