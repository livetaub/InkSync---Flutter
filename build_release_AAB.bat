@echo off
set "JAVA_HOME=C:\Users\livet\AppData\Local\Temp\openjdk17\jdk-17.0.19+10"
set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "GRADLE_OPTS=-Djavax.net.ssl.trustStoreType=Windows-ROOT"

echo ========================================================
echo   Building InkSync Release App Bundle (.aab)...
echo ========================================================
echo.

cd /d "c:\My Projects\InkSync"
call flutter clean
call flutter build appbundle --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo SUCCESS: Release AAB built!
    echo Output: build\app\outputs\bundle\release\app-release.aab
    echo ========================================================
) else (
    echo.
    echo FAILED: Build returned error code %ERRORLEVEL%
)
echo.
pause
