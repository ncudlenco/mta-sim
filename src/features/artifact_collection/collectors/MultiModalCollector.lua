--- MultiModalCollector: Unified collector for the mtasa-blue client native
--- multi-modal capture path. Replaces the per-modality NativeScreenshotCollector,
--- SegmentationCollector and DepthCollector trio with a single
--- `captureMultiModalFrame` round-trip that produces RGB, segmentation and
--- depth artifacts atomically from the D3D9 pipeline.
---
--- Path layout matches the per-modality collectors so downstream consumers see
--- the same tree:
---     [graphPath]_out/[storyId]/[cameraId]/frame_XXXX_screenshot.(jpg|png)
---     [graphPath]_out/[storyId]/[cameraId]/frame_XXXX_segmentation.png
---     [graphPath]_out/[storyId]/[cameraId]/frame_XXXX_depth.png
---     [graphPath]_out/[storyId]/[cameraId]/segmentation_mapping.json
---     [graphPath]_out/[storyId]/[cameraId]/raw.mp4        (if RGB video enabled)
---
--- @classmod MultiModalCollector

MultiModalCollector = class(ArtifactCollector, function(o, adapter, config)
    ArtifactCollector.init(o, "MultiModalCollector", config)

    if not adapter then
        error("[MultiModalCollector] adapter is required")
    end
    o.adapter = adapter

    o.globalFPS = config.framesPerSecond or 30

    -- RGB: per-frame image (JPEG preferred) + optional H.264 video.
    o.rgbImageFPS        = config.rgbImageFPS or config.nativeScreenshotImageFPS or 0
    o.rgbImageFormat     = config.rgbImageFormat or config.nativeScreenshotImageFormat or "jpeg"
    o.rgbJPEGQuality     = config.rgbJPEGQuality or config.nativeScreenshotJPEGQuality or 95
    o.rgbSaveToVideo     = config.rgbSaveToVideo ~= false   -- default on
    o.rgbInterval        = (o.rgbImageFPS > 0) and math.max(1, math.floor(o.globalFPS / o.rgbImageFPS)) or 0

    -- Segmentation: per-frame indexed PNG; video disabled (chroma subsampling
    -- corrupts per-pixel labels — see Stage 7 notes).
    o.segmentationPNGFPS = config.segmentationPNGFPS or 0
    o.segSaveToVideo     = config.segSaveToVideo or false
    o.segInterval        = (o.segmentationPNGFPS > 0) and math.max(1, math.floor(o.globalFPS / o.segmentationPNGFPS)) or 0

    -- Depth: per-frame PNG; video disabled by default for the same reason.
    o.depthPNGFPS        = config.depthPNGFPS or 0
    o.depthSaveToVideo   = config.depthSaveToVideo or false
    o.depthInterval      = (o.depthPNGFPS > 0) and math.max(1, math.floor(o.globalFPS / o.depthPNGFPS)) or 0

    o.videoFPS           = config.videoFPS or 30
    o.videoBitrate       = config.videoBitrate or 5000000

    o.videoStarted       = { [ModalityType.RAW] = false,
                             [ModalityType.SEGMENTATION] = false,
                             [ModalityType.DEPTH] = false }

    -- Rewrite the mapping JSON once every N captured frames. Small file, cheap.
    o.mappingWriteEveryNFrames = config.mappingWriteEveryNFrames or 1

    o.segmentationArmed = false
    o.tagCounter        = 0

    if DEBUG_SCREENSHOTS then
        print(string.format("[MultiModalCollector] globalFPS=%d rgb{fps=%d,fmt=%s,q=%d,video=%s} seg{fps=%d} depth{fps=%d}",
            o.globalFPS, o.rgbImageFPS, tostring(o.rgbImageFormat), o.rgbJPEGQuality, tostring(o.rgbSaveToVideo),
            o.segmentationPNGFPS, o.depthPNGFPS))
    end
end)

--- Derive the per-frame artifact path, matching NativeScreenshotCollector's scheme.
--- Format: `[graphPath]_out/[storyId]/[cameraId]/frame_XXXX_[filename]`.
---
--- @param frameId number Zero-padded (to 4 digits) in the output path.
--- @param filename string Terminal segment (e.g. `"screenshot.jpg"`).
--- @param storyId string|nil Overrides `self.config.storyId` if given.
--- @return string Absolute output path.
function MultiModalCollector:getFilePath(frameId, filename, storyId)
    local graphPath = LOAD_FROM_GRAPH or "unknown"
    if type(graphPath) == "table" then graphPath = graphPath[1] or "unknown" end

    local effectiveStoryId = storyId or self.config.storyId
    if not effectiveStoryId then
        error("[MultiModalCollector] StoryId not set — call updateConfig() after story instantiation")
    end
    local cameraId = self.config.cameraId or "unknown"
    return string.format("%s_out/%s/%s/frame_%04d_%s", graphPath, effectiveStoryId, cameraId, frameId, filename)
end

--- Build the per-session video path for a modality (`raw.mp4`, `segmentation.mp4`,
--- `depth.mp4`) from any per-frame path sharing the same parent directory.
---
--- @param anyFramePath string A per-frame path like
---     `[graphPath]_out/[storyId]/[cameraId]/frame_0001_screenshot.jpg`.
--- @param modalityName string Modality basename — `"raw"`, `"segmentation"`, or `"depth"`.
--- @return string Video path — `<parent>/<modalityName>.mp4`.
function MultiModalCollector:_deriveVideoPath(anyFramePath, modalityName)
    local parent = anyFramePath:match("(.+)/[^/]+$") or ""
    return parent .. "/" .. modalityName .. ".mp4"
end

--- Arms the D3D9 segmentation double-draw exactly once per session (idempotent).
--- Takes effect from the next rendered client frame.
function MultiModalCollector:_armSegmentationOnce()
    if self.segmentationArmed then return end
    if self.segmentationPNGFPS > 0 or self.segSaveToVideo then
        self.adapter:setSegmentationEnabled(true)
        self.segmentationArmed = true
        if DEBUG_SCREENSHOTS then
            print("[MultiModalCollector] Segmentation double-draw armed")
        end
    end
end

--- Lazy-starts the persistent H.264 encoder for a modality. No-op on subsequent calls.
---
--- @param modalityId integer One of `ModalityType.{RAW,SEGMENTATION,DEPTH}`.
--- @param modalityName string Matches `_deriveVideoPath`'s expected input.
--- @param anyFramePath string Any per-frame path; used to resolve the video output location.
function MultiModalCollector:_startVideoOnce(modalityId, modalityName, anyFramePath)
    if self.videoStarted[modalityId] then return end
    local videoPath = self:_deriveVideoPath(anyFramePath, modalityName)
    local w = self.config.widthResolution or WIDTH_RESOLUTION or 1920
    local h = self.config.heightResolution or HEIGHT_RESOLUTION or 1080
    self.adapter:startVideoRecording(modalityId, videoPath, w, h, self.videoFPS, self.videoBitrate)
    self.videoStarted[modalityId] = true
    if DEBUG_SCREENSHOTS then
        print(string.format("[MultiModalCollector] Video started: modality=%s path=%s", modalityName, videoPath))
    end
end

--- Captures all enabled modalities for the current frame.
--- Per-modality FPS gating controls whether an image file is written this
--- frame (paths are empty strings when skipped). Video submission is gated
--- per modality by its `save*ToVideo` flag, not by the interval.
---
--- Lazy-initializes video encoders on first use and arms the segmentation
--- double-draw exactly once. Periodically flushes the texture-name → color
--- map to disk (controlled by `mappingWriteEveryNFrames`).
---
--- The completion callback fires when the native C++ binding returns (all
--- artifacts on disk + video frames accepted by their encoders).
---
--- @param frameContext table Current frame context data (storyId, etc.).
--- @param frameId number Monotonically increasing frame index from the manager.
--- @param callback function Completion callback: `callback(success, width, height)`.
function MultiModalCollector:collectAndSave(frameContext, frameId, callback)
    local storyId = (frameContext and frameContext.storyId) or self.config.storyId
    if not storyId then
        error("[MultiModalCollector] StoryId not set — call updateConfig() after story instantiation")
    end

    -- Decide per-modality what to save this frame.
    local rgbPath, segPath, depthPath = "", "", ""

    local wantRGBImage   = self.rgbInterval   > 0 and (frameId % self.rgbInterval   == 0)
    local wantSegImage   = self.segInterval   > 0 and (frameId % self.segInterval   == 0)
    local wantDepthImage = self.depthInterval > 0 and (frameId % self.depthInterval == 0)

    if wantRGBImage then
        local ext = (self.rgbImageFormat == "jpeg") and ".jpg" or ".png"
        rgbPath = self:getFilePath(frameId, "screenshot" .. ext, storyId)
    end
    if wantSegImage then
        segPath = self:getFilePath(frameId, "segmentation.png", storyId)
    end
    if wantDepthImage then
        depthPath = self:getFilePath(frameId, "depth.png", storyId)
    end

    self:_armSegmentationOnce()

    local anyPath = rgbPath ~= "" and rgbPath or (segPath ~= "" and segPath or depthPath)
    if anyPath == "" then
        anyPath = self:getFilePath(frameId, "screenshot.png", storyId)
    end

    if self.rgbSaveToVideo   then self:_startVideoOnce(ModalityType.RAW,          "raw",          anyPath) end
    if self.segSaveToVideo   then self:_startVideoOnce(ModalityType.SEGMENTATION, "segmentation", anyPath) end
    if self.depthSaveToVideo then self:_startVideoOnce(ModalityType.DEPTH,        "depth",        anyPath) end

    self.tagCounter = self.tagCounter + 1
    local tag = string.format("mm_%d_%d", frameId, self.tagCounter)

    local me = self
    self.adapter:captureMultiModalFrame(tag, rgbPath, segPath, depthPath,
                                        self.rgbSaveToVideo,
                                        self.segSaveToVideo,
                                        self.depthSaveToVideo,
                                        self.rgbJPEGQuality,
                                        function(success, width, height)
            if success and (me.mappingWriteEveryNFrames > 0)
                       and (frameId % me.mappingWriteEveryNFrames == 0) then
                local graphPath = LOAD_FROM_GRAPH or "unknown"
                if type(graphPath) == "table" then graphPath = graphPath[1] or "unknown" end
                local cameraId = me.config.cameraId or "unknown"
                local mappingPath = string.format("%s_out/%s/%s/segmentation_mapping.json",
                                                   graphPath, storyId, cameraId)
                me.adapter:writeMultiModalMapping(mappingPath)
            end

            if DEBUG_SCREENSHOTS then
                print(string.format("[MultiModalCollector] Frame %d done: success=%s dims=%dx%d",
                    frameId, tostring(success), width or 0, height or 0))
            end

            if callback then callback(success, width, height) end
        end)
end

--- Tears down persistent session resources: finalizes any running video
--- encoders (so MP4 containers are valid on disk) and disarms the
--- segmentation double-draw on the client. Called by ArtifactCollectionManager
--- during `stopScheduledCollection`.
function MultiModalCollector:stopCollection()
    for modalityId, started in pairs(self.videoStarted) do
        if started then
            self.adapter:stopVideoRecording(modalityId)
            self.videoStarted[modalityId] = false
        end
    end
    if self.segmentationArmed then
        self.adapter:setSegmentationEnabled(false)
        self.segmentationArmed = false
    end
    if DEBUG_SCREENSHOTS then
        print("[MultiModalCollector] Stopped")
    end
end
