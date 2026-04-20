--- SegmentationCollector: Segmentation PNG-only collector
--- Captures indexed PNG files at configurable FPS (independent of video FPS)
--- Uses RenderModeController for game-agnostic client-side shader control
--- Implements frame skipping to achieve target PNG capture rate
---
--- @classmod SegmentationCollector

SegmentationCollector = class(ArtifactCollector, function(o, screenshotAdapter, renderModeController, config)
    ArtifactCollector.init(o, "SegmentationCollector", config)

    o.screenshotAdapter = screenshotAdapter
    o.renderModeController = renderModeController
    o.globalTextureMapping = {}  -- Accumulated texture mappings across all frames

    -- PNG capture configuration
    o.pngFPS = config.segmentationPNGFPS or 10
    o.globalFPS = config.framesPerSecond or 30
    o.captureInterval = math.max(1, math.floor(o.globalFPS / o.pngFPS))
    o.pngFrameCounter = 0

    -- Frame ID offset to compensate for Desktop Duplication frame advance
    -- Due to forceFramePresent() calls in shader enable/disable, Desktop Duplication
    -- advances internal frame counter. This offset adjusts saved frame IDs to match
    -- actual captured frame data. Default: 0
    o.frameIdOffset = config.segmentationFrameIdOffset or 0

    if not renderModeController then
        error("[SegmentationCollector] Render mode controller is required")
    end

    if DEBUG_SCREENSHOTS then
        print(string.format("[SegmentationCollector] Initialized: globalFPS=%d, pngFPS=%d, captureInterval=%d",
            o.globalFPS, o.pngFPS, o.captureInterval))
    end
end)

--- Collect segmentation frame (PNG-only, no video)
--- Implements frame skipping based on configured PNG FPS
--- Only enables shader and captures when frame should be captured
---
--- @param frameContext table Current frame context data
--- @param frameId number Sequential frame number
--- @param callback function Completion callback: callback(success, width, height)
function SegmentationCollector:collectAndSave(frameContext, frameId, callback)
    -- Check if we should capture PNG this frame
    local shouldCapturePNG = (frameId % self.captureInterval == 0)

    if not shouldCapturePNG then
        -- Skip this frame - do nothing, just callback immediately
        if callback then
            callback(true, 0, 0)
        end
        return
    end

    -- Capture this frame
    if DEBUG_SCREENSHOTS then
        print(string.format("[SegmentationCollector] Capturing PNG for frame %d (pngFrame %d)",
            frameId, self.pngFrameCounter))
    end

    -- Enable segmentation shader
    self.renderModeController:enableSegmentation(function(success, frameMapping)
        if not success then
            print(string.format("[ERROR] SegmentationCollector: Failed to enable segmentation for frame %d", frameId))
            if callback then
                callback(false, 0, 0)
            end
            return
        end

        -- Accumulate texture mappings
        if frameMapping then
            local adjustedFrameId = math.max(0, frameId + self.frameIdOffset)
            local newTextures = 0
            for texName, texInfo in pairs(frameMapping) do
                if not self.globalTextureMapping[texName] then
                    texInfo.frameId = adjustedFrameId
                    self.globalTextureMapping[texName] = texInfo
                    newTextures = newTextures + 1
                end
            end

            if DEBUG_SCREENSHOTS then
                print(string.format("[SegmentationCollector] Frame %d (adjusted: %d): +%d new textures (total: %d)",
                    frameId, adjustedFrameId, newTextures, self:_countTextures()))
            end

            self:_saveGlobalMapping(newTextures > 0)
        end

        -- Generate PNG file path with adjusted frame ID
        -- Apply offset to compensate for Desktop Duplication frame advance
        local storyId = frameContext.storyId or self.config.storyId
        if not storyId then
            error("[SegmentationCollector] StoryId not set - must call updateConfig() after story instantiation")
        end
        local adjustedFrameId = math.max(0, frameId + self.frameIdOffset)
        local filePath = self:getFilePath(adjustedFrameId, "segmentation.png", storyId)

        self.screenshotAdapter:captureFrame(
            filePath,
            "png",
            false,          -- saveToVideo = false (PNG-only, no video)
            0,              -- modalityId (used to get target resolution from ModalityManager)
            function(captureSuccess, width, height)
                if captureSuccess then
                    self.pngFrameCounter = self.pngFrameCounter + 1

                    if DEBUG_SCREENSHOTS then
                        print(string.format("[SegmentationCollector] PNG %d captured (%dx%d): %s",
                            self.pngFrameCounter - 1, width, height, filePath))
                    end
                else
                    print(string.format("[ERROR] SegmentationCollector: PNG capture failed for frame %d", frameId))
                end

                -- Disable segmentation shader after capture and wait for
                -- confirmation so normal rendering is fully restored before
                -- the next modality runs.
                self.renderModeController:disableSegmentation(function(disableSuccess)
                    if DEBUG_SCREENSHOTS then
                        print(string.format("[SegmentationCollector] Segmentation disabled and normal rendering restored (success: %s)",
                            tostring(disableSuccess)))
                    end
                    if callback then callback(captureSuccess, width, height) end
                end)
            end
        )
    end)
end

--- Stop collection and save global texture mapping
--- No video recording to stop (PNG-only collector)
function SegmentationCollector:stopCollection()
    -- Save global texture mapping
    self:_saveGlobalMapping()

    if DEBUG_SCREENSHOTS then
        print(string.format("[SegmentationCollector] Stopped. Captured %d PNGs, %d unique textures",
            self.pngFrameCounter, self:_countTextures()))
    end
end

--- Get file path for PNG artifact
--- Derives path from LOAD_FROM_GRAPH global (input JSON location)
--- Pattern: [graphPath]_out/[storyId]/[cameraId]/frame_[XXXX]_segmentation.png
---
--- @param frameId number The frame number
--- @param filename string The filename (e.g., "segmentation.png")
--- @param storyId string The story ID (optional, defaults to "unknown")
--- @return string Absolute file path
function SegmentationCollector:getFilePath(frameId, filename, storyId)
    -- Get input graph path from global
    local graphPath = LOAD_FROM_GRAPH or "unknown"

    -- If graphPath is a table (array of graphs), use first one
    if type(graphPath) == "table" then
        graphPath = graphPath[1] or "unknown"
    end

    -- Output is: [graphPath]_out
    local outputBase = graphPath .. "_out"

    -- Get story ID (fail-fast if missing)
    local effectiveStoryId = storyId or self.config.storyId
    if not effectiveStoryId then
        error("[SegmentationCollector] StoryId not set - must call updateConfig() after story instantiation")
    end

    -- Get camera ID from config
    local cameraId = self.config.cameraId or "unknown"

    -- Format frame ID with leading zeros (e.g., "0001", "0002")
    local frameIdStr = string.format("%04d", frameId)

    -- Construct path: [graphPath]_out/[storyId]/[cameraId]/frame_[XXXX]_[filename]
    local filePath = string.format("%s/%s/%s/frame_%s_%s",
        outputBase, effectiveStoryId, cameraId, frameIdStr, filename)

    return filePath
end

--- Count textures in global mapping
--- @return number Number of unique textures
function SegmentationCollector:_countTextures()
    local count = 0
    for _ in pairs(self.globalTextureMapping) do
        count = count + 1
    end
    return count
end

--- Save global texture mapping to JSON file
--- @param hasNewTextures boolean|nil If true, logs verbose output; if false/nil, only logs errors
function SegmentationCollector:_saveGlobalMapping(hasNewTextures)
    if not self.globalTextureMapping or self:_countTextures() == 0 then
        if DEBUG_SCREENSHOTS then
            print("[SegmentationCollector] No texture mapping to save")
        end
        return
    end

    -- Determine output path (same directory as PNG outputs)
    local graphPath = LOAD_FROM_GRAPH or "unknown"
    if type(graphPath) == "table" then
        graphPath = graphPath[1] or "unknown"
    end

    local outputBase = graphPath .. "_out"
    local storyId = self.config.storyId
    if not storyId then
        error("[SegmentationCollector] StoryId not set - must call updateConfig() after story instantiation")
    end
    local cameraId = self.config.cameraId or "unknown"
    local outputPath = string.format("%s/%s/%s/segmentation_mapping.json",
        outputBase, storyId, cameraId)

    -- Only log verbose output when there are new textures (reduces spam)
    if DEBUG_SCREENSHOTS and hasNewTextures then
        print(string.format("[SegmentationCollector] Saving global texture mapping to: %s (%d unique textures)",
            outputPath, self:_countTextures()))
    end

    -- Save to JSON file
    local fileHandle = fileCreate(outputPath)
    if fileHandle then
        local jsonStr = toJSON(self.globalTextureMapping, true)  -- true for pretty print
        fileWrite(fileHandle, jsonStr)
        fileClose(fileHandle)

        -- Log successful save when there are new textures or when called from stopCollection
        if hasNewTextures or hasNewTextures == nil then
            print(string.format("[SegmentationCollector] Saved global texture mapping: %s (%d unique textures)",
                outputPath, self:_countTextures()))
        end
    else
        print(string.format("[ERROR] SegmentationCollector: Failed to create mapping file: %s", outputPath))
    end
end

