--- MTARenderModeController: MTA-specific render mode controller
--- Controls client-side rendering modes via MTA's triggerClientEvent system
--- Manages event handlers for shader ready confirmations
---
--- @classmod MTARenderModeController

MTARenderModeController = class(RenderModeControllerBase, function(o, spectatorElement)
    RenderModeControllerBase.init(o)
    o.name = "MTARenderModeController"
    o.spectator = spectatorElement
    o.eventHandlersRegistered = false
    o.pendingCallback = nil
    o.pendingDisableCallback = nil  -- Callback for shader removal confirmation
    o.lastFrameMapping = nil  -- Store frame mapping for access by collectors

    -- Register event handlers once
    o:_registerEventHandlers()

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTARenderModeController] Initialized for spectator: %s",
            tostring(spectatorElement)))
    end
end)

--- Register event handlers for shader ready confirmations
--- Handlers are registered once and persist for the lifetime of the controller
function MTARenderModeController:_registerEventHandlers()
    if self.eventHandlersRegistered then
        return
    end

    local controller = self  -- Capture for closure

    -- Register segmentation ready handler
    addEvent("onSegmentationReady", true)
    addEventHandler("onSegmentationReady", self.spectator, function(frameMapping)
        if DEBUG_SCREENSHOTS then
            local mappingCount = frameMapping and getTableSize(frameMapping) or 0
            print(string.format("[MTARenderModeController] Segmentation mode ready (received %d texture mappings)",
                mappingCount))
        end

        controller.lastFrameMapping = frameMapping
        controller.currentMode = "segmentation"

        if controller.pendingCallback then
            local callback = controller.pendingCallback
            controller.pendingCallback = nil
            callback(true, frameMapping)
        end
    end)

    -- Register segmentation disabled handler
    addEvent("onSegmentationDisabled", true)
    addEventHandler("onSegmentationDisabled", self.spectator, function()
        if DEBUG_SCREENSHOTS then
            print("[MTARenderModeController] Segmentation mode disabled (normal rendering restored)")
        end

        controller.currentMode = "normal"

        -- Invoke pending disable callback if present
        if controller.pendingDisableCallback then
            local callback = controller.pendingDisableCallback
            controller.pendingDisableCallback = nil
            callback(true)
        end
    end)

    -- Register depth ready handler
    addEvent("onDepthReady", true)
    addEventHandler("onDepthReady", self.spectator, function()
        if DEBUG_SCREENSHOTS then
            print("[MTARenderModeController] Depth mode ready")
        end

        controller.currentMode = "depth"

        if controller.pendingCallback then
            local callback = controller.pendingCallback
            controller.pendingCallback = nil
            callback(true)
        end
    end)

    -- Register depth disabled handler (mirrors onSegmentationDisabled so the
    -- collector can wait for normal rendering to fully resume before moving on).
    addEvent("onDepthDisabled", true)
    addEventHandler("onDepthDisabled", self.spectator, function()
        if DEBUG_SCREENSHOTS then
            print("[MTARenderModeController] Depth mode disabled (normal rendering restored)")
        end

        controller.currentMode = "normal"

        if controller.pendingDisableCallback then
            local callback = controller.pendingDisableCallback
            controller.pendingDisableCallback = nil
            callback(true)
        end
    end)

    self.eventHandlersRegistered = true

    if DEBUG_SCREENSHOTS then
        print("[MTARenderModeController] Event handlers registered")
    end
end

--- Enable segmentation rendering mode on client
--- Triggers MTA client event and stores callback for confirmation
---
--- @param callback function Called when segmentation mode is active: callback(success)
function MTARenderModeController:enableSegmentation(callback)
    if not self.spectator or not isElement(self.spectator) then
        print("[ERROR] MTARenderModeController: Invalid spectator element")
        if callback then
            callback(false)
        end
        return
    end

    self.pendingCallback = callback

    -- Trigger MTA client-side event
    triggerClientEvent(self.spectator, "onRenderSegmentation", self.spectator, true)

    if DEBUG_SCREENSHOTS then
        print("[MTARenderModeController] Triggered segmentation mode on client")
    end
end

--- Disable segmentation rendering mode on client
--- Restores normal rendering and waits for 2 frames before invoking callback
---
--- @param callback function Optional callback when normal rendering is confirmed: callback(success)
function MTARenderModeController:disableSegmentation(callback)
    if not self.spectator or not isElement(self.spectator) then
        print("[ERROR] MTARenderModeController: Invalid spectator element")
        if callback then
            callback(false)
        end
        return
    end

    -- Store callback for confirmation event
    if callback then
        self.pendingDisableCallback = callback
    end

    -- Trigger MTA client-side event to restore normal rendering
    -- Client will wait 2 frames and send onSegmentationDisabled event
    triggerClientEvent(self.spectator, "onRenderSegmentation", self.spectator, false)

    if DEBUG_SCREENSHOTS then
        print("[MTARenderModeController] Disabled segmentation mode (waiting for confirmation)")
    end
end

--- Enable depth rendering mode on client
--- Triggers MTA client event and stores callback for confirmation
---
--- @param callback function Called when depth mode is active: callback(success)
function MTARenderModeController:enableDepth(callback)
    if not self.spectator or not isElement(self.spectator) then
        print("[ERROR] MTARenderModeController: Invalid spectator element")
        if callback then
            callback(false)
        end
        return
    end

    self.pendingCallback = callback

    -- Trigger MTA client-side event
    triggerClientEvent(self.spectator, "onRenderDepth", self.spectator, true)

    if DEBUG_SCREENSHOTS then
        print("[MTARenderModeController] Triggered depth mode on client")
    end
end

--- Disable depth rendering mode on client.
--- Restores normal rendering and waits for the client's render-confirmation
--- before invoking the callback (mirrors disableSegmentation).
---
--- @param callback function Optional callback when normal rendering is confirmed: callback(success)
function MTARenderModeController:disableDepth(callback)
    if not self.spectator or not isElement(self.spectator) then
        print("[ERROR] MTARenderModeController: Invalid spectator element")
        if callback then
            callback(false)
        end
        return
    end

    if callback then
        self.pendingDisableCallback = callback
    end

    -- Client waits for N rendered frames then fires onDepthDisabled.
    triggerClientEvent(self.spectator, "onRenderDepth", self.spectator, false)

    if DEBUG_SCREENSHOTS then
        print("[MTARenderModeController] Disabled depth mode (waiting for confirmation)")
    end
end

--- Get the last frame mapping received from client
--- @return table|nil Frame mapping with texture→{color, modelIds} data
function MTARenderModeController:getLastFrameMapping()
    return self.lastFrameMapping
end

--- Cleanup event handlers on destruction
function MTARenderModeController:destroy()
    -- Event handlers are removed automatically when spectator element is destroyed
    self.pendingCallback = nil
    self.pendingDisableCallback = nil
    self.lastFrameMapping = nil

    if DEBUG_SCREENSHOTS then
        print("[MTARenderModeController] Destroyed")
    end
end

--- Helper function to get table size
--- @param t table Table to count
--- @return number Number of key-value pairs
function getTableSize(t)
    if type(t) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end
