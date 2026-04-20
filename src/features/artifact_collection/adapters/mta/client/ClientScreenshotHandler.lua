--- ClientScreenshotHandler: Client-side screenshot capture and saving
-- Handles screenshot capture using dxScreenSource and saves locally to disk
-- Eliminates network latency by not sending pixel data to server
--

-- Global screen source (created once, reused for all captures)
local screenSource = nil
local QUALITY = 100
local DEBUG_SCREENSHOTS = true

--- Initialize screen source on resource start
addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Create screen source with configured resolution
    local width = WIDTH_RESOLUTION or 1920
    local height = HEIGHT_RESOLUTION or 1080

    screenSource = dxCreateScreenSource(width, height)

    if not screenSource then
        outputDebugString("[ClientScreenshotHandler] ERROR: Failed to create screen source!", 1)
        outputDebugString("[ClientScreenshotHandler] Screenshot capture will not work!", 1)
    else
        if DEBUG_SCREENSHOTS then
            outputDebugString(string.format("[ClientScreenshotHandler] Screen source created (%dx%d)", width, height))
        end
    end
end)

--- Handle screenshot capture request from server
-- Server sends: tag, width, height, filePath
-- Client: captures screen, notifies server immediately, saves to disk in parallel
addEvent("onCaptureScreenshot", true)
addEventHandler("onCaptureScreenshot", root, function(tag, width, height, filePath)
    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientScreenshotHandler] Capture request: tag=%s, path=%s",
            tostring(tag), tostring(filePath)))
    end

    -- Check if screen source is available
    if not screenSource then
        outputDebugString("[ClientScreenshotHandler] ERROR: Screen source not initialized!", 1)
        triggerServerEvent("onScreenshotCaptured", localPlayer, tag, false)
        return
    end

    -- Update screen source with current frame
    local updateSuccess = dxUpdateScreenSource(screenSource)
    if not updateSuccess then
        outputDebugString("[ClientScreenshotHandler] ERROR: Failed to update screen source!", 1)
        triggerServerEvent("onScreenshotCaptured", localPlayer, tag, false)
        return
    end

    -- Get pixels from screen source
    local pixels = dxGetTexturePixels(screenSource)
    if not pixels then
        outputDebugString("[ClientScreenshotHandler] ERROR: Failed to get texture pixels!", 1)
        triggerServerEvent("onScreenshotCaptured", localPlayer, tag, false)
        return
    end

    -- Notify server immediately (capture succeeded - don't wait for disk write)
    triggerServerEvent("onScreenshotCaptured", localPlayer, tag, true)

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientScreenshotHandler] Capture succeeded, notified server: %s", tag))
    end

    -- Convert pixels to JPEG format (happens in parallel, non-blocking for server)
    local jpeg = dxConvertPixels(pixels, "jpeg", QUALITY)
    if not jpeg then
        outputDebugString(string.format("[ClientScreenshotHandler] ERROR: Failed to convert pixels to JPEG: %s", filePath), 1)
        return
    end

    -- Save to disk (parallel, non-blocking)
    local file = fileCreate(filePath)
    if not file then
        outputDebugString(string.format("[ClientScreenshotHandler] ERROR: Failed to create file: %s", filePath), 1)
        return
    end

    local writeSuccess = fileWrite(file, jpeg)
    fileClose(file)

    if not writeSuccess then
        outputDebugString(string.format("[ClientScreenshotHandler] ERROR: Failed to write to file: %s", filePath), 1)
        return
    end

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientScreenshotHandler] Saved to disk: %s", filePath))
    end
end)

--- Cleanup on resource stop
addEventHandler("onClientResourceStop", resourceRoot, function()
    if screenSource then
        destroyElement(screenSource)
        screenSource = nil

        if DEBUG_SCREENSHOTS then
            outputDebugString("[ClientScreenshotHandler] Screen source destroyed")
        end
    end
end)
