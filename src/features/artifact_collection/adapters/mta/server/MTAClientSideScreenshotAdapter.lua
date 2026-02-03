--- MTAClientSideScreenshotAdapter: Server-side adapter for client-side screenshots
-- Coordinates with client to trigger screenshot capture without network latency
-- Client captures and saves locally, server receives instant confirmation only
--
-- @classmod MTAClientSideScreenshotAdapter
-- @license MIT

MTAClientSideScreenshotAdapter = class(ScreenshotAdapterBase, function(o, params)
    ScreenshotAdapterBase.init(o)
    o.name = "MTAClientSideScreenshotAdapter"
    if not params.spectator or not isElement(params.spectator) then
        error("[MTAClientSideScreenshotAdapter] Invalid spectator element")
        return false
    end

    o.spectator = params.spectator  -- The player/spectator element

    -- Register event handler for client confirmations
    o:registerEventHandler()
end)

--- Register the server-side event handler for client confirmations
-- This is called automatically during initialization
function MTAClientSideScreenshotAdapter:registerEventHandler()
    if self.eventHandlerRegistered then
        return
    end

    -- Capture self in local variable for closure
    local adapter = self

    -- Register event handler for client confirmation messages
    addEvent("onScreenshotCaptured", true)
    addEventHandler("onScreenshotCaptured", root, function(tag, success)
        if DEBUG_SCREENSHOTS then
            print(string.format("[MTAClientSideScreenshotAdapter] Client confirmation received: tag=%s, success=%s",
                tostring(tag), tostring(success)))
        end

        -- Route to adapter's callback system
        adapter:onScreenshotCaptured(tag, success)
    end)

    self.eventHandlerRegistered = true

    if DEBUG_SCREENSHOTS then
        print("[MTAClientSideScreenshotAdapter] Event handler registered for client confirmations")
    end
end

--- Trigger screenshot capture on client
-- Sends file path to client so it knows where to save
-- Client will send confirmation back via onScreenshotCaptured event
--
-- @param tag string Unique tag to identify this screenshot
-- @param width number Screenshot width
-- @param height number Screenshot height
-- @param filePath string Absolute file path where client should save
-- @param callback function Called when client confirms capture: callback(success)
-- @return boolean True if trigger was successful
function MTAClientSideScreenshotAdapter:captureScreenshot(tag, width, height, filePath, callback)
    -- Store callback for when client confirms
    self:_storePending(tag, callback)

    -- Trigger client-side capture event (no pixel data sent over network)
    triggerClientEvent(self.spectator, "onCaptureScreenshot", self.spectator, tag, width, height, filePath)

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTAClientSideScreenshotAdapter] Triggered client capture: tag=%s, path=%s",
            tag, filePath))
    end

    return true
end

--- Handle screenshot capture confirmation from client
-- Client sends instant confirmation after capture (before disk write completes)
--
-- @param tag string The tag that was passed to captureScreenshot
-- @param success boolean Whether client capture succeeded
-- @return boolean True if callback was found and invoked
function MTAClientSideScreenshotAdapter:onScreenshotCaptured(tag, success)
    local pending = self:_retrievePending(tag)

    if not pending then
        if DEBUG_SCREENSHOTS then
            print("[MTAClientSideScreenshotAdapter] No pending screenshot for tag: " .. tostring(tag))
        end
        return false
    end

    -- Invoke callback (client saved screenshot to disk)
    if pending.callback then
        pending.callback(success, nil)
    end

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTAClientSideScreenshotAdapter] Callback invoked (tag: %s, success: %s)",
            tag, tostring(success)))
    end

    return true
end
