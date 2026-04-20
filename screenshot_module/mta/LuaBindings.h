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

    /// Get native capture metadata for downstream coordinate-space mapping.
    /// Lua: getNativeCaptureMetadata() -> table or nil
    /// Returns nil if the backend is not initialized. Otherwise:
    /// {
    ///   viewport       = {w, h},                      -- GetClientRect dims
    ///   chrome         = {left, top, right, bottom},  -- auto-detected OS chrome
    ///   cropInViewport = {left, top, right, bottom},  -- viewport-side crops (constants)
    ///   visibleRect    = {x, y, w, h},                -- post-crop region in viewport coords
    ///   savedDims      = { [modalityId] = {w, h}, ... } -- per-modality output dims
    /// }
    int lua_getNativeCaptureMetadata(lua_State* L);

    /// Register all Lua functions
    void RegisterFunctions(lua_State* L);

    /// Helper: Invoke Lua callback (main thread only)
    void InvokeLuaCallback(lua_State* L, int callbackRef, bool success, int width, int height);

    /// Helper: Queue Lua callback for execution on main thread
    void QueueLuaCallback(lua_State* L, int callbackRef, bool success, int width, int height);
}
