@echo off
echo Dokploy Skill Suite - Installer
echo ========================================

set "SKILLS_DIR=%USERPROFILE%\.hermes\skills\devops"

if not exist "%SKILLS_DIR%\dokploy" mkdir "%SKILLS_DIR%\dokploy"

echo Installing to %SKILLS_DIR%\dokploy\
xcopy /E /Y "%~dp0*" "%SKILLS_DIR%\dokploy\" >nul

echo.
echo Done.
echo.
echo Next steps:
echo   1. set DOKPLOY_API_KEY=your-key-here
echo   2. In Hermes: /dokploy
echo.
echo Docs: https://github.com/m4xx101/dokploy-skills

pause
