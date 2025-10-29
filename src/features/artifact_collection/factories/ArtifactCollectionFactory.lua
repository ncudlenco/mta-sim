--- ArtifactCollectionFactory: Game-agnostic factory for artifact collection components
--- Creates managers and collectors based on configuration
--- Does NOT depend on game-specific entities (MTA elements, FiveM natives, etc.)
---
--- @classmod ArtifactCollectionFactory
--- @author Claude Code
--- @license MIT

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
        segmentationFrameIdOffset = self.config.segmentationFrameIdOffset  -- Frame ID offset for Desktop Duplication compensation
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

    -- Create depth collector
    local collector = DepthCollector(screenshotAdapter, renderModeController, {
        cameraId = spectatorData.id,
        videoFPS = self.config.videoFPS,
        videoBitrate = self.config.videoBitrate,
        framesPerSecond = self.config.framesPerSecond,
        modalityId = ModalityType.DEPTH
    })

    if DEBUG_SCREENSHOTS then
        print(string.format("[ArtifactCollectionFactory] Created depth collector for: %s",
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

    for i, spectatorData in ipairs(spectatorsData) do
        -- Create and register segmentation collector if enabled
        local segmentationCollector = self:createSegmentationCollector(spectatorData)
        if segmentationCollector then
            manager:registerCollector(segmentationCollector)
            if DEBUG then
                print(string.format("[ArtifactCollectionFactory] Registered segmentation collector for %s", spectatorData.id))
            end
        end

        -- Always create raw collector (primary modality)
        local rawCollector = self:createScreenshotCollector(spectatorData)
        if rawCollector then
            manager:registerCollector(rawCollector)
            if DEBUG then
                print(string.format("[ArtifactCollectionFactory] Registered raw collector for %s", spectatorData.id))
            end
        end

        -- Create and register depth collector if enabled
        local depthCollector = self:createDepthCollector(spectatorData)
        if depthCollector then
            manager:registerCollector(depthCollector)
            if DEBUG then
                print(string.format("[ArtifactCollectionFactory] Registered depth collector for %s", spectatorData.id))
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
