@echo off
echo ========================================
echo Building screenshot_core.lib
echo ========================================

REM Set up VS 2019 environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat"

REM Create build directory
if not exist build mkdir build

set CORE_SRC=core/VideoEncoder.cpp core/ModalityManager.cpp core/FrameBuffer.cpp core/MediaFoundationUtils.cpp

echo Compiling core library...
cl /c /MD /O2 /EHsc /std:c++17 %CORE_SRC% /I"core"

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Compilation failed
    pause
    exit /b 1
)

echo Creating static library...
lib VideoEncoder.obj ModalityManager.obj FrameBuffer.obj MediaFoundationUtils.obj /OUT:build/screenshot_core.lib

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Library creation failed
    pause
    exit /b 1
)

echo Cleaning up object files...
del *.obj

echo.
echo build\screenshot_core.lib built successfully!
echo.