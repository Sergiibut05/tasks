@echo off
REM Usage:
REM   Optional: set STRAPI_TOKEN=YOUR_TOKEN (only if your API requires it)
REM   Optional: set STRAPI_BASE_URL=http://localhost:1337
REM   Optional: set SOURCE_API_URL=https://dragonball-api.com/api/characters
REM   Run: scripts\import-characters.bat

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0import-characters.ps1"

if %ERRORLEVEL% NEQ 0 (
  echo Import failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo Import completed successfully.
