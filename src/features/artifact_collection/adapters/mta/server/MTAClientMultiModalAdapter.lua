--- MTAClientMultiModalAdapter: Server-side adapter for the client-side
--- multi-modal capture native path (mtasa-blue core.dll + CMultiModalCapture).
---
--- Each capture is atomic across all three modalities (RGB / segmentation /
--- depth) in one client call. Unlike MTAClientSideScreenshotAdapter, which
--- captures only the final composited frame, this adapter taps into the D3D9
--- pipeline directly — segmentation comes from a per-draw-call texture-color
--- hook and depth comes from an INTZ depth-stencil sample, so both modalities
--- match the RGB frame exactly with zero game disruption.
---
--- @classmod MTAClientMultiModalAdapter

MTAClientMultiModalAdapter = class(ScreenshotAdapterBase, function(o, params)
    ScreenshotAdapterBase.init(o)
    o.name = "MTAClientMultiModalAdapter"
    if not params or not params.spectator or not isElement(params.spectator) then
        error("[MTAClientMultiModalAdapter] Invalid spectator element")
    end
    o.spectator = params.spectator

    -- The client-side C++ writes files via raw Win32 APIs relative to the
    -- CLIENT'S working directory (the GTA San Andreas install, wherever
    -- gta_sa.exe launched from). That's rarely the server's resource tree —
    -- so if ARTIFACT_UNIFIED_OUTPUT_BASE is set, use it verbatim as an
    -- absolute prefix. Otherwise fall back to a relative prefix that only
    -- happens to work when the client CWD is the MTA install root.
    local absoluteBase = ARTIFACT_UNIFIED_OUTPUT_BASE
    if absoluteBase and absoluteBase ~= "" then
        if absoluteBase:sub(-1) ~= "/" and absoluteBase:sub(-1) ~= "\\" then
            absoluteBase = absoluteBase .. "/"
        end
        o.clientSidePathPrefix = absoluteBase
    else
        local resourceName = getResourceName(getThisResource())
        o.clientSidePathPrefix = "server/mods/deathmatch/resources/" .. resourceName .. "/"
    end

    o:registerEventHandler()
end)

--- Prepend the client-side path prefix to a relative path. Absolute paths
--- (drive-letter or UNC) are returned unchanged. Empty strings pass through
--- so "skip this modality" stays "skip this modality".
local function isAbsolute(p)
    return p and p ~= "" and (p:match("^[A-Za-z]:") or p:match("^[\\/][\\/]"))
end

function MTAClientMultiModalAdapter:_rewritePath(path)
    if not path or path == "" then return "" end
    if isAbsolute(path) then return path end
    return self.clientSidePathPrefix .. path
end

function MTAClientMultiModalAdapter:registerEventHandler()
    if self.eventHandlerRegistered then return end

    local adapter = self
    addEvent("onMultiModalFrameCaptured", true)
    addEventHandler("onMultiModalFrameCaptured", root, function(tag, success, width, height)
        if DEBUG_SCREENSHOTS then
            print(string.format("[MTAClientMultiModalAdapter] Client ack: tag=%s success=%s dims=%sx%s",
                tostring(tag), tostring(success), tostring(width), tostring(height)))
        end
        adapter:_onFrameCaptured(tag, success, width, height)
    end)

    self.eventHandlerRegistered = true
end

--- Capture all enabled modalities atomically on the client.
---
--- @param tag string Unique request id (used to match the client's ack)
--- @param rgbPath string|nil Output image path for RGB (empty / nil = skip image)
--- @param segPath string|nil Output image path for segmentation (empty / nil = skip)
--- @param depthPath string|nil Output image path for depth (empty / nil = skip)
--- @param saveRgbToVideo boolean Submit RGB frame to its video encoder
--- @param saveSegToVideo boolean Submit seg frame to its video encoder
--- @param saveDepthToVideo boolean Submit depth frame to its video encoder
--- @param jpegQuality number JPEG quality (0..100), used only for JPEG outputs
--- @param callback function Completion callback: callback(success, width, height)
function MTAClientMultiModalAdapter:captureMultiModalFrame(tag, rgbPath, segPath, depthPath,
                                                           saveRgbToVideo, saveSegToVideo, saveDepthToVideo,
                                                           jpegQuality, callback)
    self:_storePending(tag, callback)
    triggerClientEvent(self.spectator, "onCaptureMultiModalFrame", self.spectator, tag,
                       self:_rewritePath(rgbPath),
                       self:_rewritePath(segPath),
                       self:_rewritePath(depthPath),
                       saveRgbToVideo and true or false,
                       saveSegToVideo and true or false,
                       saveDepthToVideo and true or false,
                       jpegQuality or 95)
    return true
end

function MTAClientMultiModalAdapter:_onFrameCaptured(tag, success, width, height)
    local pending = self:_retrievePending(tag)
    if not pending then return false end
    if pending.callback then pending.callback(success, width, height) end
    return true
end

--- Start a persistent H.264 encoder for one modality.
---
--- @param modalityId integer 0=RGB, 1=SEG, 2=DEPTH (see ModalityType)
--- @param videoPath string Output MP4 path
--- @param width integer
--- @param height integer
--- @param fps integer
--- @param bitrate integer bits/second
function MTAClientMultiModalAdapter:startVideoRecording(modalityId, videoPath, width, height, fps, bitrate)
    triggerClientEvent(self.spectator, "onStartMultiModalVideo", self.spectator,
                       modalityId, self:_rewritePath(videoPath),
                       width or 1920, height or 1080, fps or 30, bitrate or 5000000)
    return true
end

function MTAClientMultiModalAdapter:stopVideoRecording(modalityId)
    triggerClientEvent(self.spectator, "onStopMultiModalVideo", self.spectator, modalityId)
    return true
end

--- Arms or disarms the segmentation double-draw in the D3D9 proxy. Takes
--- effect from the next rendered frame on the client.
function MTAClientMultiModalAdapter:setSegmentationEnabled(enabled)
    triggerClientEvent(self.spectator, "onSetMultiModalSegmentation", self.spectator,
                       enabled and true or false)
    return true
end

--- Write the accumulated texture-name → color map to disk (same schema as
--- SegmentationCollector's global mapping).
function MTAClientMultiModalAdapter:writeMultiModalMapping(path)
    triggerClientEvent(self.spectator, "onWriteMultiModalMapping", self.spectator, self:_rewritePath(path))
    return true
end

--- Native-backend availability marker consumed by ArtifactCollectionFactory.
--- True because this adapter takes over all three modalities itself.
function MTAClientMultiModalAdapter:isUnified()
    return true
end
