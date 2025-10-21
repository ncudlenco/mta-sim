--- ArtifactCollectionManager: Central coordinator for artifact collection
-- Orchestrates the freeze/collect/unfreeze cycle using a SimulationFreezeAdapter
--
-- State machine flow:
--   Idle → Freezing → Collecting → Unfreezing → Idle
--
-- @classmod ArtifactCollectionManager
-- @author Claude Code
-- @license MIT

ArtifactCollectionManager = class(function(o, freezeAdapter, config)
    o.name = "ArtifactCollectionManager"
    o.freezeAdapter = freezeAdapter
    o.config = config or {}
    o.collectors = {}
    o.currentState = "idle"
    o.currentFrameId = 0
    o.currentCollectorIndex = 0
    o.collectionTimeout = config.timeout or 10000 -- 10 seconds default
    o.timeoutTimer = nil

    -- Scheduled collection fields
    o.schedulerTimer = nil
    o.collectionInterval = nil
    o.framesCollected = 0
    o.isSchedulingActive = false
    o.completionCallback = nil
    o.collectionCallback = nil
end)

--- Collection states
local CollectionState = {
    IDLE = "idle",
    FREEZING = "freezing",
    COLLECTING = "collecting",
    UNFREEZING = "unfreezing",
    ERROR = "warning"
}

--- Register a collector for artifact collection
-- Collectors are executed in registration order during collection
--
-- @param collector ArtifactCollector The collector to register
function ArtifactCollectionManager:registerCollector(collector)
    if not collector then
        error("Cannot register nil collector")
    end

    table.insert(self.collectors, collector)

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Registered collector: %s (total: %d)",
            collector.name, #self.collectors))
    end
end

--- Update configuration for manager and all registered collectors
--- Used to set storyId after story is instantiated
---
--- @param configUpdates table Configuration updates to apply {storyId = "...", ...}
function ArtifactCollectionManager:updateConfig(configUpdates)
    if not configUpdates then
        return
    end

    -- Update manager's own config
    for key, value in pairs(configUpdates) do
        self.config[key] = value
    end

    -- Propagate to all collectors
    for _, collector in ipairs(self.collectors) do
        if collector.config then
            for key, value in pairs(configUpdates) do
                collector.config[key] = value
            end
        end
    end

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Updated config: storyId=%s",
            tostring(configUpdates.storyId)))
    end
end

--- Get current collection state
-- @return string Current state
function ArtifactCollectionManager:getState()
    return self.currentState
end

--- Check if currently collecting
-- @return boolean True if in any active collection state
function ArtifactCollectionManager:isCollecting()
    return self.currentState ~= CollectionState.IDLE
end

--- Trigger frame collection
-- Initiates the freeze → collect → unfreeze cycle
--
-- @param frameContext table Context data for the current frame
-- @return boolean True if collection was started successfully
function ArtifactCollectionManager:triggerFrameCollection(frameContext)
    if self:isCollecting() then
        if DEBUG then
            print("[ArtifactCollectionManager] Collection already in progress, skipping")
        end
        return false
    end

    self.currentFrameId = self.currentFrameId + 1
    self.currentCollectorIndex = 0
    self.frameContext = frameContext or {}

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Starting collection for frame %d", self.currentFrameId))
    end

    -- Start the collection process
    self:_transitionTo(CollectionState.FREEZING)
    self:_freeze()

    return true
end

--- Internal: Transition to a new state
-- @param newState string The state to transition to
function ArtifactCollectionManager:_transitionTo(newState)
    local oldState = self.currentState
    self.currentState = newState

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] State: %s → %s", oldState, newState))
    end
end

--- Internal: Freeze the simulation
function ArtifactCollectionManager:_freeze()
    if self.currentState ~= CollectionState.FREEZING then
        return
    end

    local success = self.freezeAdapter:freeze()

    if not success then
        print("[WARNING] Failed to freeze simulation")
        self:_handleError("Failed to freeze simulation")
        return
    end

    -- Start timeout timer
    self:_startTimeout()

    -- Move to collecting state
    self:_transitionTo(CollectionState.COLLECTING)
    self:_collectNext()
end

--- Internal: Collect artifacts from next collector in sequence
function ArtifactCollectionManager:_collectNext()
    if self.currentState ~= CollectionState.COLLECTING then
        return
    end

    self.currentCollectorIndex = self.currentCollectorIndex + 1

    -- Check if all collectors have finished
    if self.currentCollectorIndex > #self.collectors then
        if DEBUG then
            print("[ArtifactCollectionManager] All collectors finished")
        end
        self:_cancelTimeout()
        self:_unfreeze()
        return
    end

    -- Get next collector
    local collector = self.collectors[self.currentCollectorIndex]

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Executing collector %d/%d: %s",
            self.currentCollectorIndex, #self.collectors, collector.name))
    end

    -- Execute collector with callback for completion
    local success, err = pcall(function()
        collector:collectAndSave(self.frameContext, self.currentFrameId, function(collectorSuccess)
            self:_onCollectorComplete(collector, collectorSuccess)
        end)
    end)

    if not success then
        print(string.format("[Warning] Collector %s failed: %s", collector.name, tostring(err)))
        -- Continue to next collector despite error
        self:_collectNext()
    end
end

--- Internal: Handle collector completion
-- @param collector The collector that completed
-- @param success boolean Whether collection succeeded
function ArtifactCollectionManager:_onCollectorComplete(collector, success)
    if self.currentState ~= CollectionState.COLLECTING then
        if DEBUG then
            print(string.format("[ArtifactCollectionManager] Collector %s completed but not in COLLECTING state", collector.name))
        end
        return
    end

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Collector %s completed (success: %s)",
            collector.name, tostring(success)))
    end

    -- Proceed to next collector
    self:_collectNext()
end

--- Internal: Unfreeze the simulation
function ArtifactCollectionManager:_unfreeze()
    if self.currentState ~= CollectionState.COLLECTING then
        return
    end

    self:_transitionTo(CollectionState.UNFREEZING)

    local success = self.freezeAdapter:unfreeze()

    if not success then
        print("[WARNING] Failed to unfreeze simulation")
    end

    -- Return to idle state
    self:_transitionTo(CollectionState.IDLE)

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Frame %d collection complete (total: %d)",
            self.currentFrameId, self.framesCollected))
    end

    -- Schedule next collection if still active
    self:_scheduleNextCollection()
end

--- Internal: Start timeout timer for collection
function ArtifactCollectionManager:_startTimeout()
    if self.timeoutTimer then
        self.timeoutTimer:destroy()
        self.freezeAdapter:removeExcludedTimer(self.timeoutTimer)
    end

    self.timeoutTimer = Timer(function()
        print(string.format("[WARNING] Collection timeout after %dms", self.collectionTimeout))
        self:_handleError("Collection timeout")
    end, self.collectionTimeout, 1)

    -- Exclude this timer from being paused during freeze
    self.freezeAdapter:excludeTimer(self.timeoutTimer)
end

--- Internal: Cancel timeout timer
function ArtifactCollectionManager:_cancelTimeout()
    if self.timeoutTimer then
        self.freezeAdapter:removeExcludedTimer(self.timeoutTimer)
        self.timeoutTimer:destroy()
        self.timeoutTimer = nil
    end
end

--- Internal: Handle error during collection
-- @param errorMessage string Description of the error
function ArtifactCollectionManager:_handleError(errorMessage)
    self:_cancelTimeout()

    if DEBUG then
        print("[ArtifactCollectionManager] WARNING: " .. tostring(errorMessage))
    end

    -- Try to unfreeze if we're frozen
    if self.freezeAdapter:isFrozen() then
        self.freezeAdapter:unfreeze()
    end

    self:_transitionTo(CollectionState.ERROR)

    -- Reset to idle after a short delay
    Timer(function()
        self:_transitionTo(CollectionState.IDLE)
    end, 100, 1)
end

--- Get statistics about current collection
-- @return table Statistics including frame count, collector count, etc.
function ArtifactCollectionManager:getStats()
    return {
        currentFrame = self.currentFrameId,
        collectorCount = #self.collectors,
        currentState = self.currentState,
        isCollecting = self:isCollecting()
    }
end

--- Start scheduled collection with one-shot timers
--- Collection callback is invoked on each collection cycle to build frameContext
---
--- @param collectionCallback function Called on each collection: collectionCallback(frameId, triggerCollection)
---   - frameId: current frame number
---   - triggerCollection: function(frameContext) to call with frame context built by story
--- @param completionCallback function Called when scheduling stops
--- @return boolean True if scheduling started successfully
function ArtifactCollectionManager:startScheduledCollection(collectionCallback, completionCallback)
    if self.isSchedulingActive then
        print("[ArtifactCollectionManager] Already scheduling")
        return false
    end

    self.collectionCallback = collectionCallback
    self.completionCallback = completionCallback
    self.isSchedulingActive = true
    self.framesCollected = 0

    -- Calculate interval from config
    self.collectionInterval = self.config:getCollectionInterval()

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Starting scheduled collection (interval: %dms)",
            self.collectionInterval))
    end

    -- Schedule first collection
    self:_scheduleNextCollection()

    return true
end

--- Internal: Schedule next collection using one-shot timer
--- Called after each unfreeze completes
function ArtifactCollectionManager:_scheduleNextCollection()
    if not self.isSchedulingActive then
        return
    end

    local me = self
    -- Create one-shot timer for next collection
    self.schedulerTimer = Timer(function()
        if DEBUG_SCREENSHOTS then
            print(string.format("[ArtifactCollectionManager] Triggering scheduled collection for frame %d",
                me.framesCollected + 1))
        end
        me.freezeAdapter:removeExcludedTimer(me.schedulerTimer)
        me.schedulerTimer = nil
        -- Increment frame counter BEFORE collection
        me.framesCollected = me.framesCollected + 1

        -- Ask story to provide frameContext and trigger collection
        if me.collectionCallback then
            if DEBUG_SCREENSHOTS then
                print("[ArtifactCollectionManager] Invoking collection callback")
            end
            me.collectionCallback(
                me.framesCollected,
                function(frameContext)
                    if frameContext == nil then
                        if DEBUG_SCREENSHOTS then
                            print("[ArtifactCollectionManager] Frame context is nil, skipping collection. Rescheduling")
                        end
                        -- Skip collection, schedule next
                        me:_scheduleNextCollection()
                        return
                    end
                    if DEBUG_SCREENSHOTS then
                        print("[ArtifactCollectionManager] Collection callback triggered collection. Triggering frame collection.")
                    end
                    me:triggerFrameCollection(frameContext)
                end
            )
        end
    end, self.collectionInterval, 1) -- ONE-SHOT timer

    -- Exclude from freeze
    self.freezeAdapter:excludeTimer(self.schedulerTimer)
end

--- Stop scheduled collection
--- Cancels pending timer, stops all collectors (finalizes videos), and triggers completion callback
function ArtifactCollectionManager:stopScheduledCollection()
    if not self.isSchedulingActive then
        return
    end

    self.isSchedulingActive = false

    -- Cancel pending timer
    if self.schedulerTimer then
        self.freezeAdapter:removeExcludedTimer(self.schedulerTimer)
        self.schedulerTimer:destroy()
        self.schedulerTimer = nil
    end

    -- Stop all collectors (finalizes video recordings)
    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Stopping %d collectors", #self.collectors))
    end

    for i, collector in ipairs(self.collectors) do
        if collector.stopCollection then
            local success, err = pcall(function()
                collector:stopCollection()
            end)

            if not success then
                print(string.format("[WARNING] Failed to stop collector %s: %s", collector.name, tostring(err)))
            end
        end
    end

    if DEBUG then
        print(string.format("[ArtifactCollectionManager] Stopped scheduled collection (collected %d frames)",
            self.framesCollected))
    end

    -- Trigger completion callback
    if self.completionCallback then
        self.completionCallback()
        self.completionCallback = nil
    end

    self.collectionCallback = nil
end

--- Check if scheduling is active
--- @return boolean True if actively scheduling collections
function ArtifactCollectionManager:isScheduling()
    return self.isSchedulingActive
end

--- Get collection statistics
--- @return table Statistics including frames collected, scheduling status, interval
function ArtifactCollectionManager:getCollectionStats()
    return {
        framesCollected = self.framesCollected,
        isScheduling = self.isSchedulingActive,
        collectionInterval = self.collectionInterval
    }
end

--- Cleanup and reset the manager
function ArtifactCollectionManager:destroy()
    self:_cancelTimeout()

    -- Stop scheduled collection if active
    if self.isSchedulingActive then
        self:stopScheduledCollection()
    end

    if self.freezeAdapter:isFrozen() then
        self.freezeAdapter:unfreeze()
    end

    self.collectors = {}
    self:_transitionTo(CollectionState.IDLE)

    if DEBUG then
        print("[ArtifactCollectionManager] Destroyed")
    end
end
