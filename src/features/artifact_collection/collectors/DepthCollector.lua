--- DepthCollector: Depth PNG-only collector.
--- Captures grayscale linear-depth PNG files at a configurable FPS independent
--- of the global capture rate. Structurally mirrors SegmentationCollector:
--- standalone ArtifactCollector subclass, no video recording (the native
--- screenshot module's GPU encoder only handles RGB), shader is enabled per
--- capture via RenderModeController and disabled after PNG is written.
---
--- @classmod DepthCollector

DepthCollector = class(ArtifactCollector, function(o, screenshotAdapter, renderModeController, config)
    ArtifactCollector.init(o, "DepthCollector", config)

    o.screenshotAdapter = screenshotAdapter
    o.renderModeController = renderModeController

    o.pngFPS = config.depthPNGFPS or 10
    o.globalFPS = config.framesPerSecond or 30
    o.captureInterval = math.max(1, math.floor(o.globalFPS / o.pngFPS))
    o.pngFrameCounter = 0

    if not renderModeController then
        error("[DepthCollector] Render mode controller is required")
    end

    if DEBUG_SCREENSHOTS then
        print(string.format("[DepthCollector] Initialized: globalFPS=%d, pngFPS=%d, captureInterval=%d",
            o.globalFPS, o.pngFPS, o.captureInterval))
    end
end)

--- Collect depth frame (PNG-only, no video).
--- Frame skipping based on configured PNG FPS; only enables the depth shader
--- on frames that will be captured, to avoid unnecessary shader churn.
---
--- @param frameContext table Current frame context data
--- @param frameId number Sequential frame number
--- @param callback function Completion callback: callback(success, width, height)
function DepthCollector:collectAndSave(frameContext, frameId, callback)
    local shouldCapturePNG = (frameId % self.captureInterval == 0)

    if not shouldCapturePNG then
        if callback then
            callback(true, 0, 0)
        end
        return
    end

    if DEBUG_SCREENSHOTS then
        print(string.format("[DepthCollector] Capturing PNG for frame %d (pngFrame %d)",
            frameId, self.pngFrameCounter))
    end

    self.renderModeController:enableDepth(function(success)
        if not success then
            print(string.format("[ERROR] DepthCollector: Failed to enable depth for frame %d", frameId))
            if callback then
                callback(false, 0, 0)
            end
            return
        end

        local storyId = frameContext.storyId or self.config.storyId
        if not storyId then
            error("[DepthCollector] StoryId not set - must call updateConfig() after story instantiation")
        end
        local filePath = self:getFilePath(frameId, "depth.png", storyId)

        self.screenshotAdapter:captureFrame(
            filePath,
            "png",
            false,  -- saveToVideo = false (PNG-only, no video)
            0,      -- modalityId (resolution lookup; depth uses default)
            function(captureSuccess, width, height)
                if captureSuccess then
                    self.pngFrameCounter = self.pngFrameCounter + 1
                    if DEBUG_SCREENSHOTS then
                        print(string.format("[DepthCollector] PNG %d captured (%dx%d): %s",
                            self.pngFrameCounter - 1, width, height, filePath))
                    end
                else
                    print(string.format("[ERROR] DepthCollector: PNG capture failed for frame %d", frameId))
                end

                -- Wait for the next raw-render frames to flush before handing control
                -- back to the caller — mirrors SegmentationCollector so the following
                -- raw capture doesn't still see the depth shader on-screen.
                self.renderModeController:disableDepth(function(disableSuccess)
                    if DEBUG_SCREENSHOTS then
                        print(string.format("[DepthCollector] Depth disabled and normal rendering restored (success: %s)",
                            tostring(disableSuccess)))
                    end
                    if callback then
                        callback(captureSuccess, width, height)
                    end
                end)
            end
        )
    end)
end

--- Stop collection. No video to finalize and no per-frame mapping to flush.
function DepthCollector:stopCollection()
    if DEBUG_SCREENSHOTS then
        print(string.format("[DepthCollector] Stopped. Captured %d PNGs", self.pngFrameCounter))
    end
end

--- Build absolute path for a depth PNG artifact.
--- Pattern: [graphPath]_out/[storyId]/[cameraId]/frame_[XXXX]_depth.png
---
--- @param frameId number The frame number
--- @param filename string The filename (e.g., "depth.png")
--- @param storyId string Optional story override
--- @return string Absolute file path
function DepthCollector:getFilePath(frameId, filename, storyId)
    local graphPath = LOAD_FROM_GRAPH or "unknown"
    if type(graphPath) == "table" then
        graphPath = graphPath[1] or "unknown"
    end
    local outputBase = graphPath .. "_out"

    local effectiveStoryId = storyId or self.config.storyId
    if not effectiveStoryId then
        error("[DepthCollector] StoryId not set - must call updateConfig() after story instantiation")
    end

    local cameraId = self.config.cameraId or "unknown"
    local frameIdStr = string.format("%04d", frameId)

    return string.format("%s/%s/%s/frame_%s_%s",
        outputBase, effectiveStoryId, cameraId, frameIdStr, filename)
end
