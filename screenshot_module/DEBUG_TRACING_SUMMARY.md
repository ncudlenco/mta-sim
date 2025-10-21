# Screenshot Module Debug Tracing Implementation

## Overview

Comprehensive debug tracing has been added to all screenshot_module components (core and mta) with a centralized feature flag control.

## Feature Flag Control

### Global Flag
```cpp
// Defined in mta/main.cpp
bool ENABLE_SCREENSHOT_MODULE_DEBUG = false;
```

### Lua API
```lua
-- Enable debug tracing
setScreenshotModuleDebug(true)

-- Disable debug tracing
setScreenshotModuleDebug(false)

-- Get current state
local isEnabled = getScreenshotModuleDebug()
```

## Components with Debug Tracing

### Core Components (screenshot_module/core/)

1. **DebugLog.h** - Centralized debug logging system
   - `DEBUG_LOG(component, message)` - Simple log
   - `DEBUG_LOG_FMT(component, format, ...)` - Formatted log
   - `DEBUG_LOG_HR(component, operation, hr)` - HRESULT log

2. **ModalityManager.cpp**
   - Constructor/Destructor
   - StartRecording (parameters, success/failure)
   - AddFrame (both texture and pixel variants)
   - StopRecording
   - IsRecording
   - StopAll

3. **VideoEncoder.cpp**
   - Constructor/Destructor
   - Start (Media Foundation init, sink writer, stream config)
   - AddFrame (texture and pixel variants, frame counts)
   - Stop (finalize, frame totals)

4. **FrameBuffer.cpp**
   - CreateCroppedTexture (dimensions, cropping)
   - CreateStagingTexture (dimensions)
   - MapTexture (pitch info)
   - UnmapTexture

5. **MediaFoundationUtils.cpp**
   - Initialize (MFStartup)
   - Shutdown (MFShutdown)

### MTA Components (screenshot_module/mta/)

1. **DesktopDuplicationBackend.cpp**
   - Constructor/Destructor
   - Initialize (full D3D11/DXGI setup chain)
   - Cleanup
   - CaptureFrame (frame acquisition, cropping)
   - ReleaseFrame

2. **AsyncFrameProcessor.cpp** (TO BE COMPLETED)
   - Worker thread lifecycle
   - Frame submission
   - Texture cloning
   - PNG saving
   - Video encoding submission

3. **main.cpp** (TO BE COMPLETED)
   - Module initialization
   - Lua function registration
   - Debug flag control functions

## Debug Log Output

All debug output goes to three destinations:
1. **File**: `screenshot_module_debug.log` (append mode)
2. **Console**: `stdout` via `printf()`
3. **Debugger**: `OutputDebugStringA()` for Visual Studio

## Log Format

```
[Component] Message
[Component] Operation: details
[Component] Operation failed: HRESULT=0x########
```

### Example Output

```
[DesktopDuplicationBackend] Constructor: cropTop=40
[DesktopDuplicationBackend] Initialize called
[DesktopDuplicationBackend] Creating D3D11 device...
[DesktopDuplicationBackend] D3D11 device created successfully
[DesktopDuplicationBackend] Getting DXGI device...
[DesktopDuplicationBackend] Getting DXGI adapter...
[DesktopDuplicationBackend] Getting primary output...
[DesktopDuplicationBackend] Getting IDXGIOutput1 interface...
[DesktopDuplicationBackend] Creating Desktop Duplication...
[DesktopDuplicationBackend] Initialize: success, dims=1920x1040 (cropped), format=87
[ModalityManager] StartRecording: modalityId=0, path=output/video.mp4, dims=1920x1040, fps=30, bitrate=5000000
[VideoEncoder] Start: path=output/video.mp4, dims=1920x1040, fps=30, bitrate=5000000
[MediaFoundationUtils] Initialize: already initialized=0
[MediaFoundationUtils] Initialize: MFStartup success
[VideoEncoder] Start: success
[ModalityManager] StartRecording: success for modality 0
[DesktopDuplicationBackend] CaptureFrame: acquired, AccumulatedFrames=1, LastPresentTime=1234567890
[DesktopDuplicationBackend] CaptureFrame: cropping texture...
[FrameBuffer] CreateCroppedTexture: cropTop=40
[FrameBuffer] CreateCroppedTexture: source dims=1920x1080
[FrameBuffer] CreateCroppedTexture: success, cropped dims=1920x1040
[DesktopDuplicationBackend] CaptureFrame: crop success
[ModalityManager] AddFrame (texture): modalityId=0
[VideoEncoder] AddFrame (texture): frame 0
[VideoEncoder] AddFrame (texture): success, total frames=1
[ModalityManager] AddFrame (texture): modalityId=0, success=1
```

## Implementation Status

### ✅ Completed
- Core/DebugLog.h header
- Core/ModalityManager.cpp
- Core/VideoEncoder.cpp
- Core/MediaFoundationUtils.cpp
- Core/FrameBuffer.cpp
- MTA/DesktopDuplicationBackend.cpp

### ⏳ Remaining
- MTA/AsyncFrameProcessor.cpp tracing
- MTA/main.cpp debug flag initialization
- MTA/main.cpp Lua API functions
- Build script updates

## Usage

### Enable Debug for Troubleshooting

```lua
-- In server script
setScreenshotModuleDebug(true)

-- Start recording
startVideoRecording(0, "output/test.mp4", 30, 5000000)

-- Capture frames...
captureFrame("output/frame.png", false, 0)

-- Check debug log
-- File: screenshot_module_debug.log
```

### Disable Debug for Production

```lua
-- In server script
setScreenshotModuleDebug(false)  -- Default state
```

## Performance Considerations

- Debug logging adds minimal overhead when disabled (single boolean check)
- File I/O happens only when debug is enabled
- No runtime memory allocation for debug strings when disabled
- Formatted strings use stack buffers (512 bytes max)

## Thread Safety

- File logging uses individual fopen/fprintf/fclose per call
- No shared file handle to avoid cross-thread issues
- Component name and message passed as const char* (no allocation)

## Build Integration

The DebugLog.h header must be included in all traced components. No additional libraries required.

```cpp
#include "DebugLog.h"  // or "../core/DebugLog.h" for mta/ components
```

## Future Enhancements

1. Log rotation (prevent unbounded file growth)
2. Per-component debug levels (TRACE, DEBUG, INFO, WARN, ERROR)
3. Timestamp prefixes
4. Thread ID logging for multi-threaded debugging
5. Conditional compilation (#ifdef DEBUG_BUILD)
