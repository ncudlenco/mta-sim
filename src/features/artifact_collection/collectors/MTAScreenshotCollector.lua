--- MTAScreenshotCollector: Game-agnostic MTA screenshot collector
--- Orchestrates screenshot capture via server-side MTA adapter
--- Uses MTA's takeScreenShot() API which transfers pixels over network
--- Callback invoked when pixels arrive at server (disk write happens async)
--- File path uses frame-based naming: frame_[XXXX]_screenshot.jpg
---
--- @classmod MTAScreenshotCollector
--- @license MIT

MTAScreenshotCollector = class(ArtifactCollector, function(o, screenshotAdapter, config)
    ArtifactCollector.init(o, "MTAScreenshotCollector", config)
    o.screenshotAdapter = screenshotAdapter
    o.width = config.width or WIDTH_RESOLUTION or 1920
    o.height = config.height or HEIGHT_RESOLUTION or 1080

    if DEBUG_SCREENSHOTS then
        print("[MTAScreenshotCollector] Initialized with adapter: " .. (screenshotAdapter.name or "unknown"))
    end
end)

--- Get file path for screenshot artifact using frame-based naming
--- Derives path from LOAD_FROM_GRAPH global (input JSON location)
--- Pattern: [graphPath]_out/[storyId]/[cameraId]/frame_[XXXX]_screenshot.jpg
---
--- @param frameId number The frame number
--- @param filename string The filename (e.g., "screenshot.jpg")
--- @param storyId string The story ID (optional, defaults to "unknown")
--- @return string Absolute file path
function MTAScreenshotCollector:getFilePath(frameId, filename, storyId)
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
        error("[MTAScreenshotCollector] StoryId not set - must call updateConfig() after story instantiation")
    end

    -- Get camera id from config
    local cameraId = self.config.cameraId or "default"

    -- Format frame ID with leading zeros (e.g., "0001", "0002")
    local frameIdStr = string.format("%04d", frameId)

    -- Construct path: [graphPath]_out/[storyId]/[cameraId]/frame_[XXXX]_[filename]
    local filePath = string.format("%s/%s/%s/frame_%s_%s",
        outputBase, effectiveStoryId, cameraId, frameIdStr, filename)

    return filePath
end

--- Collect screenshot and trigger server-side save
--- Server captures pixels via takeScreenShot(), receives them via onPlayerScreenShot event
--- Callback invoked when pixels arrive at server (disk write happens async in background)
---
--- @param frameContext table Current frame context data (game-agnostic)
--- @param frameId number Sequential frame number
--- @param callback function Completion callback: callback(success)
function MTAScreenshotCollector:collectAndSave(frameContext, frameId, callback)
    -- Extract frame context data
    local playerId = frameContext.playerId or "unknown"
    local storyId = frameContext.storyId or self.config.storyId
    if not storyId then
        error("[MTAScreenshotCollector] StoryId not set - must call updateConfig() after story instantiation")
    end
    local playerName = frameContext.playerName or "spectator"
    local timestamp = tostring(frameContext.timestamp or frameId)

    -- Generate unique tag for this screenshot: playerId;storyId;playerName;timestamp
    local tag = playerId .. ';' .. storyId .. ';' .. playerName .. ';' .. timestamp

    -- Generate file path using frame-based naming
    local filename = "screenshot.jpg"
    local filePath = self:getFilePath(frameId, filename, storyId)

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTAScreenshotCollector] Capturing frame %d to %s", frameId, filePath))
    end

    -- Trigger server-side capture via adapter
    -- Adapter will:
    -- 1. Call spectator:takeScreenShot()
    -- 2. Wait for onPlayerScreenShot event (pixels arrive at server)
    -- 3. Invoke callback immediately (unfreeze simulation)
    -- 4. Write pixels to disk async in background
    local success = self.screenshotAdapter:captureScreenshot(
        tag,
        self.width,
        self.height,
        filePath,
        function(captureSuccess)
            -- Pixels received at server (disk write happens async)
            if DEBUG_SCREENSHOTS then
                if captureSuccess then
                    print(string.format("[MTAScreenshotCollector] Frame %d captured: %s", frameId, filePath))
                else
                    print(string.format("[MTAScreenshotCollector] Frame %d capture failed", frameId))
                end
            end

            if callback then
                callback(captureSuccess)
            end
        end
    )

    if not success then
        print("[ERROR] MTAScreenshotCollector: Failed to trigger screenshot")
        if callback then
            callback(false)
        end
    end
end
