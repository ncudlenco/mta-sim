@echo off
echo Building MTA Screenshot Module with Visual Studio 2019...

REM Set up VS 2019 environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat"

REM Create build directory
if not exist build mkdir build

REM Compile the minimal module
echo Compiling minimal version...
cl.exe /LD /MD /O2 /std:c++17 ^
    /DWIN32 /DNDEBUG /D_WINDOWS /D_USRDLL ^
    /I"C:\Program Files (x86)\Lua\5.1\include" ^
    main_exact_copy.cpp ^
    /link /OUT:build\ml_screenshot.dll ^
    "C:\Program Files (x86)\Lua\5.1\lib\lua5.1.lib" user32.lib ^
    /SUBSYSTEM:WINDOWS /DLL

if exist build\ml_screenshot.dll (
    echo Build successful!
    echo Copying to MTA modules directory...
    copy build\ml_screenshot.dll ..\..\..\modules\ml_screenshot.dll
    echo.
    echo Next steps:
    echo 1. Add to mtaserver.conf: ^<module src="screenshot_win32.dll"/^>
    echo 2. Set SCREENSHOT_MODE = "native" in ServerGlobals.lua
    echo 3. Restart MTA server
) else (
    echo Build failed!
)