@echo off
REM Optional: set STRAPI_TOKEN=YOUR_TOKEN
REM Optional: set STRAPI_BASE_URL=http://localhost:1337
REM Optional: set SOURCE_API_URL=https://dragonball-api.com/api/planets
REM Run: scripts\import-planets.bat

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0import-planets.ps1"

if %ERRORLEVEL% NEQ 0 (
  echo Import failed with exit code %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo Import completed successfully.
