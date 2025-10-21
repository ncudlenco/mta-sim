@echo off
echo Building MTA Screenshot Module with Visual Studio 2019...

REM Set up VS 2019 environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat"

REM Create build directory
if not exist build mkdir build

REM Compile the module with callback support
echo Compiling screenshot module with callback support...
cl.exe /LD /MD /O2 /std:c++17 ^
    /DWIN32 /DNDEBUG /D_WINDOWS /D_USRDLL ^
    /I"C:\Program Files (x86)\Lua\5.1\include" ^
    main.cpp ^
    /link /OUT:build\screenshot_win32.dll ^
    "C:\Program Files (x86)\Lua\5.1\lib\lua5.1.lib" user32.lib gdi32.lib gdiplus.lib ^
    /SUBSYSTEM:WINDOWS /DLL

if exist build\screenshot_win32.dll (
    echo Build successful!
    echo Copying to MTA modules directory...
    copy build\screenshot_win32.dll ..\..\..\modules\ml_screenshot.dll
    echo.
    echo Next steps:
    echo 1. Add to mtaserver.conf: ^<module src="ml_screenshot.dll"/^>
    echo 2. Set SCREENSHOT_COLLECTOR_TYPE = "native" in ServerGlobals.lua
    echo 3. Restart MTA server
) else (
    echo Build failed!
)