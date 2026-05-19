@echo off
REM ==========================================
REM InkSync One-Click Deploy
REM ==========================================
REM Double-click this file to build and deploy
REM to Cloudflare Pages (inksyncnote.com)
REM ==========================================

cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File deploy.ps1
pause
