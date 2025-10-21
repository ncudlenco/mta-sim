@echo off
echo ========================================
echo Building Complete Screenshot Module
echo ========================================

call "%~dp0build_core.bat"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Core library build failed
    exit /b 1
)

call "%~dp0build_mta.bat"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: MTA wrapper build failed
    exit /b 1
)

echo.
echo ========================================
echo All builds completed successfully!
echo ========================================
