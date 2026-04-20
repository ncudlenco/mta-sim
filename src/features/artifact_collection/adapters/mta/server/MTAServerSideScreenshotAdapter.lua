--- MTAServerSideScreenshotAdapter: Server-side adapter for MTA's native screenshot API
--- Uses takeScreenShot() to capture pixels and onPlayerScreenShot event to save them
--- Invokes callback when pixels arrive at server (disk write happens async in background)
---
--- @classmod MTAServerSideScreenshotAdapter

MTAServerSideScreenshotAdapter = class(ScreenshotAdapterBase, function(o, params)
    ScreenshotAdapterBase.init(o)
    o.name = "MTAServerSideScreenshotAdapter"

    if not params.spectator or not isElement(params.spectator) then
        error("[MTAServerSideScreenshotAdapter] Invalid spectator element")
        return false
    end

    o.spectator = params.spectator  -- The player/spectator element
    o.quality = params.quality or 75  -- JPEG quality (0-100)

    -- Register event handler for screenshot completion
    o:registerEventHandler()
end)

--- Register the server-side event handler for MTA screenshot events
--- This is called automatically during initialization
function MTAServerSideScreenshotAdapter:registerEventHandler()
    if self.eventHandlerRegistered then
        return
    end

    -- Capture self in local variable for closure
    local adapter = self

    -- Register event handler for MTA's native screenshot event
    addEventHandler("onPlayerScreenShot", root, function(theResource, status, pixels, timestamp, tag)
        if DEBUG_SCREENSHOTS then
            print(string.format("[MTAServerSideScreenshotAdapter] onPlayerScreenShot: tag=%s, status=%s, pixelSize=%d",
                tostring(tag), tostring(status), pixels and #pixels or 0))
        end

        -- Route to adapter's handler
        adapter:onPlayerScreenShot(theResource, status, pixels, timestamp, tag)
    end)

    self.eventHandlerRegistered = true

    if DEBUG_SCREENSHOTS then
        print("[MTAServerSideScreenshotAdapter] Event handler registered for onPlayerScreenShot")
    end
end

--- Trigger screenshot capture via MTA's native API
--- Sends screenshot request to client, pixels will arrive via onPlayerScreenShot event
---
--- @param tag string Unique tag to identify this screenshot (format: playerId;storyId;playerName)
--- @param width number Screenshot width
--- @param height number Screenshot height
--- @param filePath string Absolute file path where screenshot should be saved
--- @param callback function Called when screenshot is saved: callback(success)
--- @return boolean True if trigger was successful
function MTAServerSideScreenshotAdapter:captureScreenshot(tag, width, height, filePath, callback)
    -- Store callback and file path for when pixels arrive
    self:_storePending(tag, callback, filePath)

    -- Trigger MTA's native screenshot capture
    local success = self.spectator:takeScreenShot(width, height, tag, self.quality)

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTAServerSideScreenshotAdapter] Triggered takeScreenShot: tag=%s, path=%s, success=%s",
            tag, filePath, tostring(success)))
    end

    if not success then
        -- Remove from pending if trigger failed
        self:_retrievePending(tag)
        if callback then
            callback(false)
        end
    end

    return success
end

--- Store a pending screenshot with its callback and file path
--- Overrides base implementation to include filePath
--- @param tag string Unique tag for the screenshot
--- @param callback function Callback to invoke when complete
--- @param filePath string File path where screenshot should be saved
function MTAServerSideScreenshotAdapter:_storePending(tag, callback, filePath)
    self.pendingScreenshots[tag] = {
        callback = callback,
        filePath = filePath,
        timestamp = getTickCount and getTickCount() or 0,
    }
end

--- Handle screenshot pixels received from MTA
--- Invokes callback immediately when pixels arrive (allows simulation to unfreeze)
--- Then writes pixels to disk async in background
---
--- @param theResource resource The resource that triggered the screenshot
--- @param status string Screenshot status ("ok" or error message)
--- @param pixels string Raw pixel data (JPEG format)
--- @param timestamp number MTA timestamp
--- @param tag string The tag that was passed to takeScreenShot
--- @return boolean True if callback was found and invoked
function MTAServerSideScreenshotAdapter:onPlayerScreenShot(theResource, status, pixels, timestamp, tag)
    local pending = self:_retrievePending(tag)

    if not pending then
        if DEBUG_SCREENSHOTS then
            print("[MTAServerSideScreenshotAdapter] No pending screenshot for tag: " .. tostring(tag))
        end
        return false
    end

    local success = (status == "ok" and pixels ~= nil)

    -- Invoke callback IMMEDIATELY (pixels received, simulation can unfreeze)
    if pending.callback then
        pending.callback(success)
    end

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTAServerSideScreenshotAdapter] Callback invoked (tag: %s, success: %s)",
            tag, tostring(success)))
    end

    -- Update global SCREENSHOTS counter (for backward compatibility)
    local split = tag:split(';')
    local playerId = split[1]
    local storyId = split[2]

    if playerId and storyId then
        if not SCREENSHOTS then
            SCREENSHOTS = {}
        end
        if not SCREENSHOTS[playerId] then
            SCREENSHOTS[playerId] = {}
        end
        if not SCREENSHOTS[playerId][storyId] then
            SCREENSHOTS[playerId][storyId] = 0
        end
        SCREENSHOTS[playerId][storyId] = SCREENSHOTS[playerId][storyId] + 1
    end

    -- Write pixels to disk ASYNC (happens in background after unfreeze)
    if success then
        local filePath = pending.filePath

        if DEBUG_SCREENSHOTS then
            print(string.format("[MTAServerSideScreenshotAdapter] Writing pixels to: %s", filePath))
        end

        local newFile = File(filePath)
        if newFile then
            newFile:write(pixels)
            newFile:close()

            if DEBUG_SCREENSHOTS then
                print(string.format("[MTAServerSideScreenshotAdapter] Screenshot saved: %s", filePath))
            end
        else
            print(string.format("[ERROR] MTAServerSideScreenshotAdapter: Failed to create file: %s", filePath))
        end
    else
        print(string.format("[ERROR] MTAServerSideScreenshotAdapter: Screenshot failed with status: %s", tostring(status)))
    end

    return true
end
