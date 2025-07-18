@echo off
echo === MTA Story Simulation Test Runner ===
echo.

:: Check if Lua is available
lua -v >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Lua interpreter not found in PATH
    echo Please install Lua and ensure it's in your PATH
    echo You can download Lua from: https://www.lua.org/download.html
    pause
    exit /b 1
)

:: Change to the script directory
cd /d "%~dp0"

:: Run the tests
echo Running tests...
echo.
lua run_tests_standalone.lua

echo.
if %errorlevel% equ 0 (
    echo === ALL TESTS PASSED ===
) else (
    echo === SOME TESTS FAILED ===
)

pause
