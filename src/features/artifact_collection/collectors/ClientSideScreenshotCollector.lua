--- ClientSideScreenshotCollector: Game-agnostic client-side screenshot collector
-- Orchestrates screenshot capture via client-side adapter with zero network latency
-- File path is derived from input graph location (LOAD_FROM_GRAPH)
--
-- @classmod ClientSideScreenshotCollector
-- @author Claude Code
-- @license MIT

ClientSideScreenshotCollector = class(ArtifactCollector, function(o, screenshotAdapter, config)
    ArtifactCollector.init(o, "ClientSideScreenshotCollector", config)
    o.screenshotAdapter = screenshotAdapter
    o.width = config.width or WIDTH_RESOLUTION or 1920
    o.height = config.height or HEIGHT_RESOLUTION or 1080

    if DEBUG_SCREENSHOTS then
        print("[ClientSideScreenshotCollector] Initialized with adapter: " .. (screenshotAdapter.name or "unknown"))
    end
end)

--- Get file path for screenshot artifact
-- Derives path from LOAD_FROM_GRAPH global (input JSON location)
-- Pattern: [graphPath]_out/[storyId]/[spectatorId]/frame_[XXXX]_screenshot.jpg
--
-- @param frameId number The frame number
-- @param filename string The filename (e.g., "screenshot.jpg")
-- @param storyId string The story ID (optional, defaults to "unknown")
-- @return string Absolute file path
function ClientSideScreenshotCollector:getFilePath(frameId, filename, storyId)
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
        error("[ClientSideScreenshotCollector] StoryId not set - must call updateConfig() after story instantiation")
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

--- Collect screenshot and trigger client-side save
-- Client captures and saves locally, server receives instant confirmation
-- Adapter already has spectator reference, no need to extract from frameContext
--
-- @param frameContext table Current frame context data (game-agnostic)
-- @param frameId number Sequential frame number
-- @param callback function Completion callback: callback(success)
function ClientSideScreenshotCollector:collectAndSave(frameContext, frameId, callback)
    -- Generate unique tag for this screenshot (using game-agnostic data from frameContext)
    local playerId = frameContext.playerId or "unknown"
    local storyId = frameContext.storyId or self.config.storyId
    if not storyId then
        error("[ClientSideScreenshotCollector] StoryId not set - must call updateConfig() after story instantiation")
    end
    local playerName = frameContext.playerName or "spectator"
    local timestamp = tostring(frameContext.timestamp or frameId)
    local tag = playerId .. ';' .. storyId .. ';' .. playerName .. ';' .. timestamp

    -- Generate file path (client will save here) - include storyId
    local filename = "screenshot.jpg"
    local filePath = self:getFilePath(frameId, filename, storyId)

    if DEBUG_SCREENSHOTS then
        print(string.format("[ClientSideScreenshotCollector] Capturing frame %d to %s", frameId, filePath))
    end

    -- Trigger client-side capture via adapter (adapter has spectator reference)
    local success = self.screenshotAdapter:captureScreenshot(
        tag,
        self.width,
        self.height,
        filePath,
        function(captureSuccess)
            -- Client confirmed capture - callback immediately
            -- (file write happens in parallel on client)
            if DEBUG_SCREENSHOTS then
                if captureSuccess then
                    print(string.format("[ClientSideScreenshotCollector] Frame %d captured: %s",
                        frameId, filePath))
                else
                    print(string.format("[ClientSideScreenshotCollector] Frame %d capture failed",
                        frameId))
                end
            end

            if callback then
                callback(captureSuccess)
            end
        end
    )

    if not success then
        print("[ERROR] ClientSideScreenshotCollector: Failed to trigger screenshot")
        if callback then
            callback(false)
        end
    end
end
