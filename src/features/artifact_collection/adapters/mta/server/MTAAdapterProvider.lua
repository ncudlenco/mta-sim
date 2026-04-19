--- MTAAdapterProvider: MTA-specific adapter provider for artifact collection factory
--- Provides MTA-specific implementations of adapters
--- This is the bridge between game-agnostic factory and MTA-specific adapters
---
--- @classmod MTAAdapterProvider

MTAAdapterProvider = class(AdapterProviderBase, function(o)
    AdapterProviderBase.init(o)
    o.gameType = "mta"
    o.nativeScreenshotAdapter = nil  -- Singleton for native adapter
    o.renderModeControllers = {}  -- Cache controllers per spectator
    o.poseAdapters = {}  -- Cache pose adapters per spectator
    o.visibilityAdapters = {}  -- Cache visibility adapters per spectator
end)

--- Create MTA-specific freeze adapter
--- @return MTASimulationFreezeAdapter Freeze adapter instance
function MTAAdapterProvider:createFreezeAdapter()
    return MTASimulationFreezeAdapter()
end

--- Create MTA-specific client-side screenshot adapter
--- @param spectatorData SpectatorData The spectator data containing MTA element
--- @return MTAClientSideScreenshotAdapter Screenshot adapter instance
function MTAAdapterProvider:createClientScreenshotAdapter(spectatorData)
    if not spectatorData or not spectatorData.entity then
        error("[MTAAdapterProvider] Invalid spectatorData for client screenshot adapter")
    end

    return MTAClientSideScreenshotAdapter({
        spectator = spectatorData.entity
    })
end

--- Create the client-native multi-modal adapter (RGB + seg + depth in one
--- atomic call via the mtasa-blue C++ bindings). One adapter per spectator.
--- @param spectatorData SpectatorData
--- @return MTAClientMultiModalAdapter
function MTAAdapterProvider:createClientMultiModalAdapter(spectatorData)
    if not spectatorData or not spectatorData.entity then
        error("[MTAAdapterProvider] Invalid spectatorData for multi-modal adapter")
    end
    return MTAClientMultiModalAdapter({
        spectator = spectatorData.entity
    })
end

--- Create MTA-specific native screenshot adapter (singleton)
--- @return MTANativeScreenshotAdapter Screenshot adapter instance
function MTAAdapterProvider:createNativeScreenshotAdapter()
    if not self.nativeScreenshotAdapter then
        self.nativeScreenshotAdapter = MTANativeScreenshotAdapter()
        if DEBUG_SCREENSHOTS then
            print("[MTAAdapterProvider] Created singleton native screenshot adapter")
        end
    end
    return self.nativeScreenshotAdapter
end

--- Create MTA-specific render mode controller
--- Caches controllers per spectator to avoid duplicate event handlers
---
--- @param spectatorData SpectatorData The spectator data containing MTA element
--- @return MTARenderModeController Render mode controller instance
function MTAAdapterProvider:createRenderModeController(spectatorData)
    if not spectatorData or not spectatorData.entity then
        error("[MTAAdapterProvider] Invalid spectatorData for render mode controller")
    end

    -- Check if we already have a controller for this spectator
    local spectatorId = spectatorData.id
    if self.renderModeControllers[spectatorId] then
        return self.renderModeControllers[spectatorId]
    end

    -- Create new controller and cache it
    local controller = MTARenderModeController(spectatorData.entity)
    self.renderModeControllers[spectatorId] = controller

    if DEBUG_SCREENSHOTS then
        print(string.format("[MTAAdapterProvider] Created render mode controller for %s", spectatorId))
    end

    return controller
end

--- Create MTA-specific pose adapter (one per spectator, cached)
--- @param spectatorData SpectatorData The spectator data containing MTA element
--- @return MTAPoseAdapter Pose adapter instance
function MTAAdapterProvider:createPoseAdapter(spectatorData)
    if not spectatorData or not spectatorData.entity then
        error("[MTAAdapterProvider] Invalid spectatorData for pose adapter")
    end

    local spectatorId = spectatorData.id
    if self.poseAdapters[spectatorId] then
        return self.poseAdapters[spectatorId]
    end

    local adapter = MTAPoseAdapter(spectatorData.entity)
    self.poseAdapters[spectatorId] = adapter
    return adapter
end

--- Create MTA-specific visibility adapter (one per spectator, cached)
--- @param spectatorData SpectatorData The spectator data containing MTA element
--- @return MTAVisibilityAdapter Visibility adapter instance
function MTAAdapterProvider:createVisibilityAdapter(spectatorData)
    if not spectatorData or not spectatorData.entity then
        error("[MTAAdapterProvider] Invalid spectatorData for visibility adapter")
    end

    local spectatorId = spectatorData.id
    if self.visibilityAdapters[spectatorId] then
        return self.visibilityAdapters[spectatorId]
    end

    local adapter = MTAVisibilityAdapter(spectatorData.entity)
    self.visibilityAdapters[spectatorId] = adapter
    return adapter
end

--- Extract spectator data from MTA elements
--- Converts MTA-specific spectator elements to game-agnostic spectator data
---
--- @param spectators table Array of MTA player/spectator elements
--- @return table Array of SpectatorData objects
function MTAAdapterProvider:extractSpectatorData(spectators)
    local spectatorsData = {}

    for i, spectator in ipairs(spectators) do
        local spectatorId = "spectator" .. (i - 1)  -- Zero-based indexing

        -- Extract ID from element if available
        if spectator and spectator.getData then
            local elementId = spectator:getData('id')
            if elementId then
                spectatorId = elementId
            end
        end

        -- Create game-agnostic spectator data
        table.insert(spectatorsData, {
            id = spectatorId,
            entity = spectator,  -- Store MTA element reference
            gameType = "mta"
        })
    end

    if DEBUG then
        print(string.format("[MTAAdapterProvider] Extracted %d spectator data objects", #spectatorsData))
    end

    return spectatorsData
end
