--- ArtifactCollectionFactory: Game-agnostic factory for artifact collection components
--- Creates managers and collectors based on configuration
--- Does NOT depend on game-specific entities (MTA elements, FiveM natives, etc.)
---
--- @classmod ArtifactCollectionFactory

--- Spectator data structure (game-agnostic)
--- @class SpectatorData
--- @field id string Unique spectator identifier
--- @field entity any Game-specific entity reference (passed to adapter provider)
--- @field gameType string Game type ("mta", "fivem", etc.)

ArtifactCollectionFactory = class(function(o, config, adapterProvider)
    if not adapterProvider then
        error("[ArtifactCollectionFactory] Adapter provider is required")
    end

    o.config = config or ArtifactCollectionConfig.fromGlobals()
    o.adapterProvider = adapterProvider
    o.sharedNativeAdapter = nil  -- Singleton for native screenshot adapter
    -- One CoordSpaceWriter shared across all collectors so coord_space.json
    -- per (storyId, cameraId) is written at most once.
    o.coordSpaceWriter = CoordSpaceWriter()

    if DEBUG then
        print(string.format("[ArtifactCollectionFactory] Initialized (game: %s, enabled: %s, fps: %d)",
            adapterProvider:getGameType(),
            tostring(o.config:isEnabled()),
            o.config.framesPerSecond))
    end
end)

--- Create artifact collection manager with all dependencies
--- Uses adapter provider to get game-specific freeze adapter
---
--- @return ArtifactCollectionManager|nil Manager instance, or nil if disabled
function ArtifactCollectionFactory:createManager()
    if not self.config:isEnabled() then
        if DEBUG then
            print("[ArtifactCollectionFactory] Artifact collection disabled, skipping manager creation")
        end
        return nil
    end

    -- Ask adapter provider for game-specific freeze adapter
    local freezeAdapter = self.adapterProvider:createFreezeAdapter()
    if not freezeAdapter then
        print("[ERROR] ArtifactCollectionFactory: Failed to create freeze adapter")
        return nil
    end

    -- Create manager with freeze adapter and config
    local manager = ArtifactCollectionManager(freezeAdapter, self.config)

    if DEBUG then
        print("[ArtifactCollectionFactory] Created artifact collection manager")
    end

    return manager
end

--- Setup event subscriptions for artifact collection lifecycle
--- Subscribes manager to artifact collection start/stop events from camera system
--- This wiring is done by the factory to keep manager camera-agnostic
---
--- @param manager ArtifactCollectionManager The manager instance
--- @param eventBus EventBus The event bus for subscriptions
function ArtifactCollectionFactory:setupEventSubscriptions(manager, eventBus)
    if not manager or not eventBus then
        if DEBUG then
            print("[ArtifactCollectionFactory] Cannot setup subscriptions: missing dependencies")
        end
        return
    end

    -- When collection should start/resume, resume the collection schedule
    -- Frame counter is NOT reset - frames continue sequentially
    eventBus:subscribe("artifact_start_collection", "artifact_manager", function(eventData)
        manager:resumeScheduledCollection()
    end)

    -- When collection should pause, pause the collection schedule
    -- Does NOT finalize videos - just stops capturing frames temporarily
    eventBus:subscribe("artifact_stop_collection", "artifact_manager", function(eventData)
        manager:pauseScheduledCollection()
    end)

    if DEBUG then
        print("[ArtifactCollectionFactory] Setup artifact collection event subscriptions")
    end
end

--- Create screenshot collector
---
--- @param spectatorData SpectatorData The spectator data
--- @return ArtifactCollector Screenshot collector instance
function ArtifactCollectionFactory:createScreenshotCollector(spectatorData)
    local collectorType = self.config.screenshotCollectorType or "client"
    local collector = nil

    if collectorType == "native" then
        -- Check if native module is available
        if takeAsyncScreenshot then
            -- Get shared native screenshot adapter
            local screenshotAdapter = self:getSharedNativeAdapter()

            -- Create native collector
            collector = NativeScreenshotCollector(screenshotAdapter, {
                cameraId = spectatorData.id,
                videoFPS = self.config.videoFPS,
                videoBitrate = self.config.videoBitrate,
                framesPerSecond = self.config.framesPerSecond,
                modalityId = ModalityType.RAW,
                -- Image export configuration
                saveImages = self.config.nativeScreenshotSaveImages,
                imageFPS = self.config.nativeScreenshotImageFPS,
                imageFormat = self.config.nativeScreenshotImageFormat,
                jpegQuality = self.config.nativeScreenshotJPEGQuality
            })

            if DEBUG then
                print(string.format("[ArtifactCollectionFactory] Created native screenshot collector for: %s",
                    spectatorData.id))
            end
        else
            error("[ArtifactCollectionFactory] Native screenshot module not available.")
        end
    elseif collectorType == "client" then
        -- Ask adapter provider for game-specific client screenshot adapter
        local screenshotAdapter = self.adapterProvider:createClientScreenshotAdapter(spectatorData)

        -- Create client-side collector
        collector = ClientSideScreenshotCollector(screenshotAdapter, {
            cameraId = spectatorData.id,
            width = self.config.widthResolution,
            height = self.config.heightResolution
        })

        if DEBUG then
            print(string.format("[ArtifactCollectionFactory] Created client-side screenshot collector for: %s",
                spectatorData.id))
        end
    end

    return collector
end

--- Create segmentation collector (PNG-only, no video)
--- Uses native DLL-based capture with segmentation shader
--- Captures indexed PNG files at configurable FPS (independent of video FPS)
---
--- @param spectatorData SpectatorData The spectator data
--- @return SegmentationCollector|nil Segmentation collector instance, or nil if not enabled/available
function ArtifactCollectionFactory:createSegmentationCollector(spectatorData)
    -- Check if segmentation is enabled
    if not self.config.enableSegmentation then
        if DEBUG_SCREENSHOTS then
            print("[ArtifactCollectionFactory] Segmentation collection disabled in config")
        end
        return nil
    end

    -- Check if native module is available
    if not takeAsyncScreenshot then
        print("[ERROR] ArtifactCollectionFactory: Native screenshot module required for segmentation collector")
        return nil
    end

    -- Get shared native screenshot adapter
    local screenshotAdapter = self:getSharedNativeAdapter()

    -- Ask adapter provider for render mode controller
    local renderModeController = self.adapterProvider:createRenderModeController(spectatorData)

    -- Create segmentation collector (PNG-only, no video)
    local collector = SegmentationCollector(screenshotAdapter, renderModeController, {
        cameraId = spectatorData.id,
        framesPerSecond = self.config.framesPerSecond,  -- Global FPS (for frame skipping calculation)
        segmentationPNGFPS = self.config.segmentationPNGFPS,  -- Target PNG capture FPS
        segmentationFrameIdOffset = self.config.segmentationFrameIdOffset,  -- Frame ID offset for Desktop Duplication compensation
        -- storyId will be obtained from frameContext.storyId or CURRENT_STORY.Id at runtime
    })

    if DEBUG_SCREENSHOTS then
        print(string.format("[ArtifactCollectionFactory] Created segmentation collector (PNG-only) for: %s (pngFPS=%d)",
            spectatorData.id, self.config.segmentationPNGFPS or 0))
    end

    return collector
end

--- Create depth collector
--- Uses native DLL-based capture with depth shader
---
--- @param spectatorData SpectatorData The spectator data
--- @return DepthCollector|nil Depth collector instance, or nil if not enabled/available
function ArtifactCollectionFactory:createDepthCollector(spectatorData)
    -- Check if depth is enabled
    if not self.config.enableDepth then
        if DEBUG_SCREENSHOTS then
            print("[ArtifactCollectionFactory] Depth collection disabled in config")
        end
        return nil
    end

    -- Check if native module is available
    if not takeAsyncScreenshot then
        print("[ERROR] ArtifactCollectionFactory: Native screenshot module required for depth collector")
        return nil
    end

    -- Get shared native screenshot adapter
    local screenshotAdapter = self:getSharedNativeAdapter()

    -- Ask adapter provider for render mode controller
    local renderModeController = self.adapterProvider:createRenderModeController(spectatorData)

    -- Create depth collector (PNG-only, no video — the native encoder only
    -- handles RGB, so depth mirrors segmentation's standalone capture path).
    local collector = DepthCollector(screenshotAdapter, renderModeController, {
        cameraId = spectatorData.id,
        framesPerSecond = self.config.framesPerSecond,
        depthPNGFPS = self.config.depthPNGFPS
    })

    if DEBUG_SCREENSHOTS then
        print(string.format("[ArtifactCollectionFactory] Created depth collector for: %s",
            spectatorData.id))
    end

    return collector
end

--- Create the unified multi-modal collector that drives the mtasa-blue client
--- native backend. Replaces the RGB / segmentation / depth trio when
--- `config.useUnifiedMultiModal` is true.
---
--- @param spectatorData SpectatorData The spectator data
--- @return MultiModalCollector|nil Collector instance, or nil if disabled
function ArtifactCollectionFactory:createMultiModalCollector(spectatorData)
    local adapter = self.adapterProvider:createClientMultiModalAdapter(spectatorData)
    if not adapter then
        print("[ERROR] ArtifactCollectionFactory: Failed to create multi-modal adapter")
        return nil
    end

    local collector = MultiModalCollector(adapter, {
        cameraId                   = spectatorData.id,
        framesPerSecond            = self.config.framesPerSecond,
        widthResolution            = self.config.widthResolution,
        heightResolution           = self.config.heightResolution,
        videoFPS                   = self.config.videoFPS,
        videoBitrate               = self.config.videoBitrate,

        -- RGB modality (reuses the existing native-screenshot config keys).
        rgbImageFPS                = self.config.nativeScreenshotImageFPS,
        rgbImageFormat             = self.config.nativeScreenshotImageFormat,
        rgbJPEGQuality             = self.config.nativeScreenshotJPEGQuality,
        rgbSaveToVideo             = self.config.nativeScreenshotSaveImages ~= false,

        -- Segmentation modality.
        segmentationPNGFPS         = self.config.enableSegmentation and self.config.segmentationPNGFPS or 0,
        segSaveToVideo             = false,

        -- Depth modality.
        depthPNGFPS                = self.config.enableDepth and self.config.depthPNGFPS or 0,
        depthSaveToVideo           = false
    })

    if DEBUG_SCREENSHOTS then
        print(string.format("[ArtifactCollectionFactory] Created multi-modal collector for: %s", spectatorData.id))
    end

    return collector
end

--- Create event frame mapping collector
--- Maps graph events to frame IDs for video analysis
--- This is a global collector (not per-spectator)
---
--- @return EventFrameMappingCollector|nil Event frame mapping collector instance, or nil if not enabled
function ArtifactCollectionFactory:createEventFrameMappingCollector()
    -- Check if event frame mapping is enabled
    if not self.config.enableEventFrameMapping then
        if DEBUG then
            print("[ArtifactCollectionFactory] Event frame mapping disabled in config")
        end
        return nil
    end

    local collector = EventFrameMappingCollector({
        framesPerSecond = self.config.framesPerSecond
    })

    if DEBUG then
        print("[ArtifactCollectionFactory] Created event frame mapping collector")
    end

    return collector
end

--- Create spatial relations collector
--- Captures spatial relations of all visible objects relative to camera
--- This is a per-spectator collector
---
--- @param spectatorData table Spectator configuration
--- @return SpatialRelationsCollector|nil Spatial relations collector instance, or nil if not enabled
function ArtifactCollectionFactory:createSpatialRelationsCollector(spectatorData)
    -- Check if spatial relations collection is enabled
    if not self.config.enableSpatialRelations then
        if DEBUG then
            print("[ArtifactCollectionFactory] Spatial relations collection disabled in config")
        end
        return nil
    end

    local visibilityAdapter = self.adapterProvider:createVisibilityAdapter(spectatorData)
    if not visibilityAdapter then
        print("[ERROR] ArtifactCollectionFactory: Failed to create visibility adapter for spatial relations")
        return nil
    end

    local collector = SpatialRelationsCollector(visibilityAdapter, self.coordSpaceWriter, {
        cameraId = spectatorData.id,
        framesPerSecond = self.config.framesPerSecond,
        spatialRelationsFPS = self.config.spatialRelationsFPS,
        includeInvisible = self.config.spatialRelationsIncludeInvisible,
        maxDistance = self.config.spatialRelationsMaxDistance,
        includeObjectRelations = self.config.spatialRelationsIncludeObjectRelations,
        screenWidth = self.config.widthResolution,
        screenHeight = self.config.heightResolution
    })

    if DEBUG then
        print(string.format("[ArtifactCollectionFactory] Created spatial relations collector for: %s",
            spectatorData.id))
    end

    return collector
end

--- Create pose collector (3D bones + 2D screen projection per story actor)
--- Per-spectator: each spectator has its own camera matrix for projection.
---
--- @param spectatorData table Spectator configuration
--- @return PoseCollector|nil Pose collector instance, or nil if not enabled
function ArtifactCollectionFactory:createPoseCollector(spectatorData)
    if not self.config.enablePose then
        if DEBUG then
            print("[ArtifactCollectionFactory] Pose collection disabled in config")
        end
        return nil
    end

    local poseAdapter = self.adapterProvider:createPoseAdapter(spectatorData)
    if not poseAdapter then
        print("[ERROR] ArtifactCollectionFactory: Failed to create pose adapter")
        return nil
    end

    local collector = PoseCollector(poseAdapter, self.coordSpaceWriter, {
        cameraId = spectatorData.id,
        framesPerSecond = self.config.framesPerSecond,
        poseFPS = self.config.poseFPS,
        includeOffscreen = self.config.poseIncludeOffscreen,
        screenWidth = self.config.widthResolution,
        screenHeight = self.config.heightResolution
    })

    if DEBUG then
        print(string.format("[ArtifactCollectionFactory] Created pose collector for: %s",
            spectatorData.id))
    end

    return collector
end

--- Register all enabled collectors for spectators
--- Game-agnostic version - accepts spectator data, not game-specific entities
---
--- @param manager ArtifactCollectionManager The manager to register collectors with
--- @param spectatorsData table Array of SpectatorData objects
function ArtifactCollectionFactory:registerCollectors(manager, spectatorsData)
    if not manager then
        print("[WARNING] ArtifactCollectionFactory: No manager provided for collector registration")
        return
    end

    if not spectatorsData or #spectatorsData == 0 then
        print("[WARNING] ArtifactCollectionFactory: No spectators provided for collector registration")
        return
    end

    -- Register event frame mapping collector (global, not per-spectator)
    local eventMappingCollector = self:createEventFrameMappingCollector()
    if eventMappingCollector then
        manager:registerCollector(eventMappingCollector)
        if DEBUG then
            print("[ArtifactCollectionFactory] Registered event frame mapping collector")
        end
    end

    for i, spectatorData in ipairs(spectatorsData) do
        if self.config.useUnifiedMultiModal then
            -- Unified backend replaces the RGB / segmentation / depth trio with
            -- a single collector that drives all three modalities atomically.
            local multiModalCollector = self:createMultiModalCollector(spectatorData)
            if multiModalCollector then
                manager:registerCollector(multiModalCollector)
                if DEBUG then
                    print(string.format("[ArtifactCollectionFactory] Registered multi-modal collector for %s", spectatorData.id))
                end
            end
        else
            -- Legacy per-modality path: each modality is its own collector.
            local segmentationCollector = self:createSegmentationCollector(spectatorData)
            if segmentationCollector then
                manager:registerCollector(segmentationCollector)
                if DEBUG then
                    print(string.format("[ArtifactCollectionFactory] Registered segmentation collector for %s", spectatorData.id))
                end
            end

            local rawCollector = self:createScreenshotCollector(spectatorData)
            if rawCollector then
                manager:registerCollector(rawCollector)
                if DEBUG then
                    print(string.format("[ArtifactCollectionFactory] Registered raw collector for %s", spectatorData.id))
                end
            end

            local depthCollector = self:createDepthCollector(spectatorData)
            if depthCollector then
                manager:registerCollector(depthCollector)
                if DEBUG then
                    print(string.format("[ArtifactCollectionFactory] Registered depth collector for %s", spectatorData.id))
                end
            end
        end

        -- Create and register spatial relations collector if enabled
        local spatialCollector = self:createSpatialRelationsCollector(spectatorData)
        if spatialCollector then
            manager:registerCollector(spatialCollector)
            if DEBUG then
                print(string.format("[ArtifactCollectionFactory] Registered spatial relations collector for %s", spectatorData.id))
            end
        end

        -- Create and register pose collector if enabled
        local poseCollector = self:createPoseCollector(spectatorData)
        if poseCollector then
            manager:registerCollector(poseCollector)
            if DEBUG then
                print(string.format("[ArtifactCollectionFactory] Registered pose collector for %s", spectatorData.id))
            end
        end
    end

    if DEBUG then
        print(string.format("[ArtifactCollectionFactory] Finished registering collectors for %d spectators", #spectatorsData))
    end
end

--- Get shared native screenshot adapter instance
--- Creates singleton adapter to avoid multiple DLL instances
--- Uses adapter provider for game-specific implementation
---
--- @return ScreenshotAdapterBase The native screenshot adapter
function ArtifactCollectionFactory:getSharedNativeAdapter()
    if not self.sharedNativeAdapter then
        self.sharedNativeAdapter = self.adapterProvider:createNativeScreenshotAdapter()
        if DEBUG_SCREENSHOTS then
            print("[ArtifactCollectionFactory] Created shared native screenshot adapter")
        end
    end
    return self.sharedNativeAdapter
end

--- Get configuration
--- @return ArtifactCollectionConfig The configuration
function ArtifactCollectionFactory:getConfig()
    return self.config
end
