--- DepthCollector: Depth map video collector
--- Extends NativeScreenshotCollector to capture depth rendering
--- Uses RenderModeController for game-agnostic client-side shader control
--- Part of multi-modal artifact collection system
---
--- @classmod DepthCollector
--- @author Claude Code
--- @license MIT

DepthCollector = class(NativeScreenshotCollector, function(o, screenshotAdapter, renderModeController, config)
    -- Initialize parent with depth modality
    NativeScreenshotCollector.init(o, screenshotAdapter, config)
    o.name = "DepthCollector"
    o.renderModeController = renderModeController

    if not renderModeController then
        error("[DepthCollector] Render mode controller is required")
    end

    if DEBUG_SCREENSHOTS then
        print("[DepthCollector] Initialized (game-agnostic)")
    end
end)

--- Collect depth frame
--- Triggers client-side depth rendering via RenderModeController
--- Waits for event-based confirmation before capturing (no arbitrary timers!)
---
--- @param frameContext table Current frame context data
--- @param frameId number Sequential frame number
--- @param callback function Completion callback: callback(success, width, height)
function DepthCollector:collectAndSave(frameContext, frameId, callback)
    if DEBUG_SCREENSHOTS then
        print(string.format("[DepthCollector] Enabling depth mode for frame %d", frameId))
    end

    -- Enable depth rendering (event-based, no timers)
    self.renderModeController:enableDepth(function(success)
        if not success then
            print(string.format("[ERROR] DepthCollector: Failed to enable depth mode for frame %d", frameId))
            if callback then
                callback(false, 0, 0)
            end
            return
        end

        if DEBUG_SCREENSHOTS then
            print(string.format("[DepthCollector] Depth mode active, capturing frame %d", frameId))
        end

        -- Call parent collectAndSave to capture the depth-rendered frame
        NativeScreenshotCollector.collectAndSave(self, frameContext, frameId, function(captureSuccess, width, height)
            -- Restore normal rendering after capture
            self.renderModeController:disableDepth()

            if DEBUG_SCREENSHOTS then
                if captureSuccess then
                    print(string.format("[DepthCollector] Frame %d captured and rendering restored", frameId))
                else
                    print(string.format("[DepthCollector] Frame %d capture failed", frameId))
                end
            end

            -- Forward callback
            if callback then
                callback(captureSuccess, width, height)
            end
        end)
    end)
end

--- Stop collection and restore normal rendering
function DepthCollector:stopCollection()
    -- Call parent to stop video recording
    NativeScreenshotCollector.stopCollection(self)

    -- Ensure normal rendering is restored
    if self.renderModeController and not self.renderModeController:isNormalMode() then
        self.renderModeController:disableDepth()

        if DEBUG_SCREENSHOTS then
            print("[DepthCollector] Ensured normal rendering restored")
        end
    end
end
