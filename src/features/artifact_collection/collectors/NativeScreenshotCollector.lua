--- NativeScreenshotCollector: Native DLL-based screenshot collector
--- Orchestrates screenshot capture via native C++ DLL module
--- Provides callback when pixels are available in memory (before disk write)
--- File path is derived from input graph location (LOAD_FROM_GRAPH)
--- Supports multi-modal video recording (raw, segmentation, depth)
---
--- @classmod NativeScreenshotCollector
--- @license MIT

NativeScreenshotCollector = class(ArtifactCollector, function(o, screenshotAdapter, config)
    ArtifactCollector.init(o, "NativeScreenshotCollector", config)
    o.screenshotAdapter = screenshotAdapter
    o.modalityId = config.modalityId or ModalityType.RAW
    o.videoStarted = false

    -- Image capture configuration
    o.saveImages = config.saveImages or false
    o.imageFPS = config.imageFPS or 0
    o.imageFormat = config.imageFormat or "none"  -- "none", "png", "jpeg"
    o.jpegQuality = config.jpegQuality or 95
    o.globalFPS = config.framesPerSecond or 30
    o.captureInterval = (o.imageFPS > 0) and math.max(1, math.floor(o.globalFPS / o.imageFPS)) or 0
    o.imageFrameCounter = 0

    if DEBUG_SCREENSHOTS then
        print("[NativeScreenshotCollector] Initialized with adapter: " .. (screenshotAdapter.name or "unknown"))
        print("[NativeScreenshotCollector] Modality: " .. o:getModalityName(o.modalityId))
        print(string.format("[NativeScreenshotCollector] Image config: save=%s, format=%s, fps=%d, interval=%d",
            tostring(o.saveImages), o.imageFormat, o.imageFPS, o.captureInterval))
    end
end)

--- Get modality name from modality ID
--- @param modalityId number The modality ID
--- @return string Modality name ("raw", "segmentation", "depth", or "unknown")
function NativeScreenshotCollector:getModalityName(modalityId)
    if modalityId == ModalityType.RAW then
        return "raw"
    elseif modalityId == ModalityType.SEGMENTATION then
        return "segmentation"
    elseif modalityId == ModalityType.DEPTH then
        return "depth"
    else
        return "unknown"
    end
end

--- Derive video path from screenshot path
--- Pattern: [parent_folder]/[modality].mp4
--- Example: files/graphs/story1_out/story1/spectator0/raw.mp4
---
--- @param screenshotPath string The screenshot file path
--- @return string Video file path
function NativeScreenshotCollector:deriveVideoPath(screenshotPath)
    -- Extract parent folder from screenshot path
    -- screenshotPath example: "files/graphs/story1_out/story1/spectator0/frame_0001_screenshot.png"
    -- We want: "files/graphs/story1_out/story1/spectator0/raw.mp4"

    local parentFolder = screenshotPath:match("(.+)/[^/]+$") or ""
    local modalityName = self:getModalityName(self.modalityId)
    local videoPath = parentFolder .. "/" .. modalityName .. ".mp4"

    return videoPath
end

--- Start video recording (lazy initialization on first frame)
--- @param firstFramePath string Path to first frame (used to derive video path)
--- @return boolean Success
function NativeScreenshotCollector:_startVideoRecording(firstFramePath)
    if self.videoStarted then
        return true
    end

    local videoPath = self:deriveVideoPath(firstFramePath)
    local width = self.config.widthResolution or WIDTH_RESOLUTION or 1920
    local height = self.config.heightResolution or HEIGHT_RESOLUTION or 1080
    local fps = self.config.videoFPS or 30
    local bitrate = self.config.videoBitrate or 5000000

    if DEBUG_SCREENSHOTS then
        print(string.format("[NativeScreenshotCollector] Starting video recording: %s (resolution=%dx%d, fps=%d, bitrate=%d)",
            videoPath, width, height, fps, bitrate))
    end

    local success = self.screenshotAdapter:startVideoRecording(self.modalityId, videoPath, width, height, fps, bitrate)

    if success then
        self.videoStarted = true
        if DEBUG_SCREENSHOTS then
            print("[NativeScreenshotCollector] Video recording started successfully")
        end
    else
        print("[WARNING] NativeScreenshotCollector: Failed to start video recording: " .. videoPath)
    end

    return success
end

--- Get file path for screenshot artifact
--- Derives path from LOAD_FROM_GRAPH global (input JSON location)
--- Pattern: [graphPath]_out/[storyId]/[cameraId]/frame_[XXXX]_screenshot.png
---
--- @param frameId number The frame number
--- @param filename string The filename (e.g., "screenshot.png")
--- @param storyId string The story ID (optional, defaults to "unknown")
--- @return string Absolute file path
function NativeScreenshotCollector:getFilePath(frameId, filename, storyId)
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
        error("[NativeScreenshotCollector] StoryId not set - must call updateConfig() after story instantiation")
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

--- Collect screenshot and video frame using native DLL module
--- Lazy-initializes video recording on first frame
--- Image export is frame-rate based with frame skipping: frameId % captureInterval == 0
--- Callback is invoked when pixels are captured in memory (before disk write)
---
--- @param frameContext table Current frame context data
--- @param frameId number Sequential frame number
--- @param callback function Completion callback: callback(success, width, height)
function NativeScreenshotCollector:collectAndSave(frameContext, frameId, callback)
    -- Generate file path for potential image export
    local storyId = frameContext.storyId or self.config.storyId
    if not storyId then
        error("[NativeScreenshotCollector] StoryId not set - must call updateConfig() after story instantiation")
    end

    -- Lazy-initialize video recording on first frame
    if not self.videoStarted then
        local filename = "screenshot.png"  -- Dummy path for video derivation
        local filePath = self:getFilePath(frameId, filename, storyId)
        local videoStartSuccess = self:_startVideoRecording(filePath)
        if not videoStartSuccess then
            print("[WARNING] NativeScreenshotCollector: Failed to start video recording")
            if callback then
                callback(false, 0, 0)
            end
            return
        end
    end

    -- Determine if we should save image this frame (frame skipping based on FPS)
    local shouldCaptureImage = self.saveImages and
                               self.captureInterval > 0 and
                               (frameId % self.captureInterval == 0)

    -- Generate file path with correct extension if saving image
    local filePath = ""
    local imageFormat = "none"
    if shouldCaptureImage then
        local extension = (self.imageFormat == "jpeg") and ".jpg" or ".png"
        filePath = self:getFilePath(frameId, "screenshot" .. extension, storyId)
        imageFormat = self.imageFormat
    end

    if DEBUG_SCREENSHOTS then
        print(string.format("[NativeScreenshotCollector] Frame %d: video=true, image=%s (format=%s), path=%s",
            frameId, tostring(shouldCaptureImage), imageFormat, shouldCaptureImage and filePath or "none"))
    end

    -- Capture frame with new signature: (path, imageFormat, saveToVideo, modalityId, callback, jpegQuality)
    local success = self.screenshotAdapter:captureFrame(
        filePath,
        imageFormat,
        true,  -- saveToVideo = always true for raw collector
        self.modalityId,
        function(captureSuccess, width, height)
            -- Pixels captured and added to video encoder
            if captureSuccess and shouldCaptureImage then
                self.imageFrameCounter = self.imageFrameCounter + 1
            end

            if DEBUG_SCREENSHOTS then
                if captureSuccess then
                    print(string.format("[NativeScreenshotCollector] Frame %d captured (%dx%d) - modality=%s, images=%d",
                        frameId, width or 0, height or 0, self:getModalityName(self.modalityId), self.imageFrameCounter))
                else
                    print(string.format("[NativeScreenshotCollector] Frame %d capture failed", frameId))
                end
            end

            if callback then
                callback(captureSuccess, width, height)
            end
        end,
        self.jpegQuality
    )

    if not success then
        print("[WARNING] NativeScreenshotCollector: Failed to capture frame")
        if callback then
            callback(false, 0, 0)
        end
    end
end

--- Stop collection and finalize video recording
--- Called by ArtifactCollectionManager when collection ends
function NativeScreenshotCollector:stopCollection()
    if self.videoStarted then
        if DEBUG_SCREENSHOTS then
            print(string.format("[NativeScreenshotCollector] Stopping video recording for modality %s",
                self:getModalityName(self.modalityId)))
        end

        local success = self.screenshotAdapter:stopVideoRecording(self.modalityId)

        if success then
            if DEBUG_SCREENSHOTS then
                print("[NativeScreenshotCollector] Video recording stopped successfully")
            end
        else
            print("[WARNING] NativeScreenshotCollector: Failed to stop video recording")
        end

        self.videoStarted = false
    end
end

--- Check if native screenshot module is available
--- @return boolean True if the native module is loaded
function NativeScreenshotCollector:isAvailable()
    return takeAsyncScreenshot ~= nil
end

--- Get collector information
--- @return table Table with collector details
function NativeScreenshotCollector:getInfo()
    return {
        name = self.name,
        adapterName = self.screenshotAdapter and self.screenshotAdapter.name or "none",
        enabled = self.enabled,
        moduleAvailable = self:isAvailable(),
        modalityId = self.modalityId,
        modalityName = self:getModalityName(self.modalityId),
        videoStarted = self.videoStarted,
        config = self.config
    }
end
