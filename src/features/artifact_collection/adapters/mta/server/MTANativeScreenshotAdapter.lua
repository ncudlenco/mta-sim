--- MTANativeScreenshotAdapter: Server-side adapter for native DLL-based screenshots
--- Uses the screenshot_module C++ DLL for capturing screenshots directly from the game window
--- Provides callback support to notify when pixels are available in memory (before disk write)
---
--- @classmod MTANativeScreenshotAdapter
--- @author Claude Code
--- @license MIT

MTANativeScreenshotAdapter = class(ScreenshotAdapterBase, function(o)
    ScreenshotAdapterBase.init(o)
    o.name = "MTANativeScreenshotAdapter"
    o.windowTitle = "MTA: San Andreas" -- Default window title

    -- Compute resource filesystem path once at initialization
    local resourceName = getResourceName(getThisResource())
    o.resourceFSPath = "mods/deathmatch/resources/" .. resourceName .. "/"

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTANativeScreenshotAdapter] Initialized with resource path: %s", o.resourceFSPath))
    end
end)

--- Capture screenshot using native DLL module
--- The callback is invoked when pixels are available in memory (before saving to disk)
--- This allows the simulation to continue rendering immediately after capture
---
--- @param tag string Unique tag to identify this screenshot
--- @param width number Screenshot width (not used - determined by window size)
--- @param height number Screenshot height (not used - determined by window size)
--- @param filePath string Absolute file path where screenshot should be saved
--- @param callback function Called when pixels are captured: callback(success, width, height)
--- @return boolean True if capture was triggered successfully
function MTANativeScreenshotAdapter:captureScreenshot(tag, width, height, filePath, callback)
    if not takeAsyncScreenshot then
        if DEBUG_SCREENSHOTS then
            print("[MTANativeScreenshotAdapter] ERROR: screenshot_module not loaded!")
        end
        if callback then
            callback(false, 0, 0)
        end
        return false
    end

    -- Store the user callback
    self:_storePending(tag, callback)

    -- Convert relative path to absolute filesystem path based on resource root
    local absolutePath = filePath
    if not filePath:match("^[A-Za-z]:") and not filePath:match("^[\\/][\\/]") then
        -- Path is relative, prepend resource directory filesystem path (computed at init)
        absolutePath = self.resourceFSPath .. filePath

        if DEBUG_SCREENSHOTS then
            print(string.format("[MTANativeScreenshotAdapter] Converted relative path: %s -> %s", filePath, absolutePath))
        end
    end

    -- Create callback wrapper for the C++ module
    local adapter = self
    local callbackWrapper = function(success, actualWidth, actualHeight)
        if DEBUG_SCREENSHOTS then
            print(string.format("[MTANativeScreenshotAdapter] Pixels captured: tag=%s, success=%s, dimensions=%dx%d",
                tag, tostring(success), actualWidth or 0, actualHeight or 0))
        end

        -- Invoke the stored callback
        adapter:onScreenshotCaptured(tag, success, actualWidth, actualHeight)
    end

    -- Trigger native screenshot with callback
    local success = takeAsyncScreenshot(absolutePath, self.windowTitle, callbackWrapper)

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTANativeScreenshotAdapter] Triggered native capture: tag=%s, path=%s, success=%s",
            tag, filePath, tostring(success)))
    end

    return success
end

--- Handle screenshot capture completion from native module
--- This is called when pixels are available in memory (before disk write)
---
--- @param tag string The tag that was passed to captureScreenshot
--- @param success boolean Whether capture succeeded
--- @param width number Actual width of captured screenshot
--- @param height number Actual height of captured screenshot
--- @return boolean True if callback was found and invoked
function MTANativeScreenshotAdapter:onScreenshotCaptured(tag, success, width, height)
    local pending = self:_retrievePending(tag)

    if not pending then
        if DEBUG_SCREENSHOTS then
            print("[MTANativeScreenshotAdapter] No pending screenshot for tag: " .. tostring(tag))
        end
        return false
    end

    -- Invoke callback (pixels are in memory, disk write is happening in parallel)
    if pending.callback then
        pending.callback(success, width, height)
    end

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTANativeScreenshotAdapter] Callback invoked (tag: %s, success: %s, dimensions: %dx%d)",
            tag, tostring(success), width or 0, height or 0))
    end

    return true
end

--- Set the window title to capture from
--- @param title string The window title to search for
function MTANativeScreenshotAdapter:setWindowTitle(title)
    self.windowTitle = title
end

--- Register event handlers (not needed for native adapter)
--- Native callbacks are handled directly via Lua function references
function MTANativeScreenshotAdapter:registerEventHandler()
    -- Not needed - native module uses direct Lua callbacks
    self.eventHandlerRegistered = true
end

--- Start video recording for a specific modality
--- @param modalityId integer Modality ID (0=raw, 1=seg, 2=depth)
--- @param videoPath string Relative path to output MP4 file
--- @param width integer Target output video width
--- @param height integer Target output video height
--- @param fps integer Video framerate (default: 30)
--- @param bitrate integer Video bitrate (default: 5000000)
--- @return boolean Success
function MTANativeScreenshotAdapter:startVideoRecording(modalityId, videoPath, width, height, fps, bitrate)
    if not startVideoRecording then
        if DEBUG_SCREENSHOTS then
            print("[MTANativeScreenshotAdapter] ERROR: startVideoRecording not available")
        end
        return false
    end

    -- Convert relative path to absolute
    local absolutePath = self.resourceFSPath .. videoPath

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTANativeScreenshotAdapter] Starting video: modality=%d, path=%s, resolution=%dx%d",
            modalityId, absolutePath, width or 0, height or 0))
    end

    local success, err = startVideoRecording(modalityId, absolutePath, width or 1920, height or 1080, fps or 30, bitrate or 5000000)
    if not success and err then
        print("[MTANativeScreenshotAdapter] WARNING: " .. err)
    end

    return success
end

--- Stop video recording for a specific modality
--- @param modalityId integer Modality ID
--- @return boolean Success
function MTANativeScreenshotAdapter:stopVideoRecording(modalityId)
    if not stopVideoRecording then
        return false
    end

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTANativeScreenshotAdapter] Stopping video: modality=%d", modalityId))
    end

    local success, err = stopVideoRecording(modalityId)
    if not success and err then
        print("[MTANativeScreenshotAdapter] WARNING: " .. err)
    end

    return success
end

--- Capture frame with modality support
--- NEW SIGNATURE: Uses explicit image format and video flag
--- @param filePath string Relative path for image export (if imageFormat != "none")
--- @param imageFormat string Image format: "none", "png", "png_indexed", "jpeg"
--- @param saveToVideo boolean Whether to submit frame to video encoder
--- @param modalityId integer Video encoder modality ID (only used if saveToVideo=true)
--- @param callback function Callback when pixels captured: callback(success, width, height)
--- @param jpegQuality integer JPEG quality 0-100 (default: 95), only used for JPEG format
--- @return boolean Success
function MTANativeScreenshotAdapter:captureFrame(filePath, imageFormat, saveToVideo, modalityId, callback, jpegQuality)
    if not captureFrame then
        if DEBUG_SCREENSHOTS then
            print("[MTANativeScreenshotAdapter] ERROR: captureFrame not available")
        end
        if callback then
            callback(false, 0, 0)
        end
        return false
    end

    -- Convert relative path to absolute
    local absolutePath = filePath
    if filePath and filePath ~= "" and not filePath:match("^[A-Za-z]:") and not filePath:match("^[\\/][\\/]") then
        absolutePath = self.resourceFSPath .. filePath
    end

    -- Generate unique tag
    local tag = tostring(getTickCount()) .. "_" .. tostring(modalityId)

    -- Store callback
    self:_storePending(tag, callback, nil)

    -- Create callback wrapper
    local adapter = self
    local callbackWrapper = function(success, width, height)
        if DEBUG_SCREENSHOTS then
            print(string.format("[MTANativeScreenshotAdapter] Frame captured: tag=%s, format=%s, video=%s, modality=%d, %dx%d",
                tag, imageFormat or "none", tostring(saveToVideo), modalityId, width or 0, height or 0))
        end
        adapter:onScreenshotCaptured(tag, success, width, height)
    end

    -- Trigger capture with new signature
    -- C++ signature: captureFrame(path, imageFormat, saveToVideo, modalityId, callback, jpegQuality)
    local success, err = captureFrame(absolutePath, imageFormat or "none", saveToVideo, modalityId, callbackWrapper, jpegQuality or 95)
    if not success then
        if err then
            print("[MTANativeScreenshotAdapter] WARNING: " .. err)
        end
        self:_retrievePending(tag)  -- Clean up
        if callback then
            callback(false, 0, 0)
        end
    end

    return success
end
