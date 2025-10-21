@echo off
echo ========================================
echo Building ml_screenshot.dll
echo ========================================

REM Set up VS 2019 environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat"

REM Create build directory
if not exist build mkdir build

set MTA_PATH=Z:\More games\GTA San Andreas\MTA-SA1.6

set MTA_SRC=mta/DesktopDuplicationBackend.cpp mta/AsyncFrameProcessor.cpp mta/main.cpp

echo Compiling MTA wrapper...
cl /LD /MD /O2 /std:c++17 ^
   /DWIN32 /DNDEBUG /D_WINDOWS /D_USRDLL ^
   /I"C:\Program Files (x86)\Lua\5.1\include" ^
   /I"core" /I"." %MTA_SRC% ^
   /link build/screenshot_core.lib ^
   "C:\Program Files (x86)\Lua\5.1\lib\lua5.1.lib" ^
   user32.lib gdi32.lib gdiplus.lib d3d11.lib dxgi.lib ^
   mf.lib mfplat.lib mfreadwrite.lib mfuuid.lib ^
   /OUT:build/ml_screenshot.dll ^
   /SUBSYSTEM:WINDOWS /DLL

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Compilation failed
    pause
    exit /b 1
)

echo Copying to MTA modules folder...
copy /Y build\ml_screenshot.dll "..\..\..\modules\ml_screenshot.dll"

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Copy failed
    pause
    exit /b 1
)

echo.
echo ml_screenshot.dll built and copied successfully!
echo Location: ..\..\..\modules\ml_screenshot.dll
echo.