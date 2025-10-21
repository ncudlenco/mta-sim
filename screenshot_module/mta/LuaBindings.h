#pragma once

extern "C" {
    #include "lua.h"
    #include "lualib.h"
    #include "lauxlib.h"
}

#include <string>

/// Lua API bindings for screenshot module
namespace LuaBindings {
    /// Start video recording for a specific modality
    /// Lua: startVideoRecording(modalityId, outputPath, fps, bitrate) -> success, errorMsg
    int lua_startVideoRecording(lua_State* L);

    /// Stop video recording for a specific modality
    /// Lua: stopVideoRecording(modalityId) -> success, errorMsg
    int lua_stopVideoRecording(lua_State* L);

    /// Capture frame
    /// Lua: captureFrame(filePath, saveAsPNG, modalityId, callback) -> success, errorMsg
    int lua_captureFrame(lua_State* L);

    /// Register all Lua functions
    void RegisterFunctions(lua_State* L);

    /// Helper: Invoke Lua callback (main thread only)
    void InvokeLuaCallback(lua_State* L, int callbackRef, bool success, int width, int height);

    /// Helper: Queue Lua callback for execution on main thread
    void QueueLuaCallback(lua_State* L, int callbackRef, bool success, int width, int height);
}
