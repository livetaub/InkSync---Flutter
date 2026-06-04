@echo off
set "JAVA_HOME=C:\Users\livet\AppData\Local\Temp\openjdk17\jdk-17.0.19+10"
set "KEYSTORE_PATH=c:\My Projects\InkSync\android\inksync-release-key.jks"

echo ========================================================
echo   InkSync Keystore Generator
echo ========================================================
echo.
echo This script will generate your Android release key.
echo Please enter a password when prompted (write it down!).
echo.

if exist "%KEYSTORE_PATH%" (
    echo WARNING: Keystore already exists at %KEYSTORE_PATH%
    echo If you want to recreate it, delete the file first.
    pause
    exit /b 1
)

"%JAVA_HOME%\bin\keytool.exe" -genkey -v -keystore "%KEYSTORE_PATH%" -keyalg RSA -keysize 2048 -validity 10000 -alias inksync

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo SUCCESS: Keystore generated at:
    echo   %KEYSTORE_PATH%
    echo ========================================================
) else (
    echo.
    echo ERROR: Keystore generation failed!
)
echo.
pause
