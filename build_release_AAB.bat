@echo off
:: 0. Locate or download JDK 17
set "JAVA_HOME=%LOCALAPPDATA%\openjdk17"
if not exist "%JAVA_HOME%\bin\java.exe" (
    echo ========================================================
    echo   Java Development Kit JDK 17 is missing.
    echo   Downloading portable OpenJDK 17 Temurin...
    echo   This is a one-time setup. Please wait...
    echo ========================================================
    echo.
    if exist "%LOCALAPPDATA%\openjdk17_tmp" rd /s /q "%LOCALAPPDATA%\openjdk17_tmp"
    mkdir "%LOCALAPPDATA%\openjdk17_tmp"
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10+7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.10_7.zip' -OutFile '%LOCALAPPDATA%\openjdk17_tmp\jdk.zip'"
    echo Extracting JDK...
    powershell -Command "Expand-Archive -Path '%LOCALAPPDATA%\openjdk17_tmp\jdk.zip' -DestinationPath '%LOCALAPPDATA%\openjdk17_tmp'"
    
    for /f "tokens=*" %%i in ('dir /b /ad "%LOCALAPPDATA%\openjdk17_tmp"') do (
        move "%LOCALAPPDATA%\openjdk17_tmp\%%i" "%JAVA_HOME%"
    )
    rd /s /q "%LOCALAPPDATA%\openjdk17_tmp"
)
set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "GRADLE_OPTS=-Djavax.net.ssl.trustStoreType=Windows-ROOT"

cd /d "c:\My Projects\InkSync"

echo ========================================================
echo   InkSync Release App Bundle (.aab) Version Manager
echo ========================================================
echo.

:: 1. Read current version from pubspec.yaml
for /f "tokens=2 delims=: " %%a in ('findstr /r "^version:" pubspec.yaml') do set "CURRENT_VERSION=%%a"

:: 2. Split version into Name (before +) and Number (after +)
for /f "tokens=1,2 delims=+" %%a in ("%CURRENT_VERSION%") do (
    set "CURRENT_BUILD_NAME=%%a"
    set "CURRENT_BUILD_NUMBER=%%b"
)

echo Current Version: %CURRENT_BUILD_NAME%
echo Current Build Number: %CURRENT_BUILD_NUMBER%
echo.

:: 3. Prompt user for new version values
set /p "NEW_BUILD_NAME=Enter new Version Name (e.g., 1.0.1) [Press Enter to keep %CURRENT_BUILD_NAME%]: "
if "%NEW_BUILD_NAME%"=="" set "NEW_BUILD_NAME=%CURRENT_BUILD_NAME%"

set /p "NEW_BUILD_NUMBER=Enter new Build Number (e.g., 2) [Press Enter to keep %CURRENT_BUILD_NUMBER%]: "
if "%NEW_BUILD_NUMBER%"=="" set "NEW_BUILD_NUMBER=%CURRENT_BUILD_NUMBER%"

echo.
echo Updating pubspec.yaml to version: %NEW_BUILD_NAME%+%NEW_BUILD_NUMBER%...
powershell -Command "(Get-Content pubspec.yaml) -replace '^version: .*', 'version: %NEW_BUILD_NAME%+%NEW_BUILD_NUMBER%' | Set-Content pubspec.yaml"

echo.
echo ========================================================
echo   Building InkSync Release App Bundle (.aab)...
echo ========================================================
echo.

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
