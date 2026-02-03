--- EventFrameMappingCollector: Maps graph events to frame IDs for video analysis
--- Subscribes to graph_event_start and graph_event_end events via EventBus
--- Outputs minimal JSON mapping: {eventId, startFrame, endFrame}
--- Timestamps can be calculated externally as: timestamp_ms = frameId * (1000 / fps)
---
--- IMPORTANT: Writes to file on EVERY event update (start or end) to prevent data loss
--- If the process crashes, all events up to the last update are preserved
---
--- Output structure:
--- {
---   "fps": 30,
---   "events": [
---     {"eventId": "a1_e5", "startFrame": 42, "endFrame": 78},
---     {"eventId": "a2_e1", "startFrame": 120, "endFrame": null},  -- Event started but not ended
---     ...
---   ]
--- }
---
--- @classmod EventFrameMappingCollector
--- @license MIT

EventFrameMappingCollector = class(ArtifactCollector, function(o, config)
    ArtifactCollector.init(o, "EventFrameMappingCollector", config)

    o.fps = config.framesPerSecond or 30
    o.events = {}  -- Stores all events indexed by eventId: {eventId -> {eventId, startFrame, endFrame}}
    o.pendingUpdates = {}  -- Tracks which events need frame assignment: {eventId -> {pendingStart, pendingEnd}}
    o.outputPath = nil  -- Will be set after story ID is available

    -- Subscribe to graph event start/end via EventBus
    local eventBus = EventBus:getInstance()

    eventBus:subscribe("graph_event_start", "event_frame_mapper", function(eventData)
        o:onEventStart(eventData)
    end)

    eventBus:subscribe("graph_event_end", "event_frame_mapper", function(eventData)
        o:onEventEnd(eventData)
    end)

    if DEBUG then
        print("[EventFrameMappingCollector] Initialized with fps=" .. o.fps)
        print("[EventFrameMappingCollector] Subscribed to graph_event_start and graph_event_end")
    end
end)

--- Handle graph event start
--- Creates or updates event entry and marks for start frame assignment
---
--- @param eventData table Event data: {eventId, actorId, actionName}
function EventFrameMappingCollector:onEventStart(eventData)
    local eventId = eventData.eventId

    if not eventId then
        if DEBUG then
            print("[EventFrameMappingCollector] WARNING: Received event_start without eventId")
        end
        return
    end

    -- Create event entry if it doesn't exist
    if not self.events[eventId] then
        self.events[eventId] = {
            eventId = eventId,
            startFrame = nil,
            endFrame = nil
        }
    end

    -- Mark as needing start frame assignment
    if not self.pendingUpdates[eventId] then
        self.pendingUpdates[eventId] = {}
    end
    self.pendingUpdates[eventId].pendingStart = true

    if DEBUG then
        print("[EventFrameMappingCollector] Event start received: " .. eventId)
    end
end

--- Handle graph event end
--- Creates or updates event entry and marks for end frame assignment
---
--- @param eventData table Event data: {eventId, actorId, actionName}
function EventFrameMappingCollector:onEventEnd(eventData)
    local eventId = eventData.eventId

    if not eventId then
        if DEBUG then
            print("[EventFrameMappingCollector] WARNING: Received event_end without eventId")
        end
        return
    end

    -- Create event entry if it doesn't exist
    if not self.events[eventId] then
        self.events[eventId] = {
            eventId = eventId,
            startFrame = nil,
            endFrame = nil
        }
    end

    -- Mark as needing end frame assignment
    if not self.pendingUpdates[eventId] then
        self.pendingUpdates[eventId] = {}
    end
    self.pendingUpdates[eventId].pendingEnd = true

    if DEBUG then
        print("[EventFrameMappingCollector] Event end received: " .. eventId)
    end
end

--- Get file path for event frame mapping JSON
--- Derives path from LOAD_FROM_GRAPH global (input JSON location)
--- Pattern: [graphPath]_out/[storyId]/event_frame_mapping.json
---
--- @param storyId string The story ID
--- @return string Absolute file path
function EventFrameMappingCollector:getOutputPath(storyId)
    if self.outputPath then
        return self.outputPath
    end

    -- Get input graph path from global
    local graphPath = LOAD_FROM_GRAPH or "unknown"

    -- If graphPath is a table (array of graphs), use first one
    if type(graphPath) == "table" then
        graphPath = graphPath[1] or "unknown"
    end

    -- Output is: [graphPath]_out/[storyId]/event_frame_mapping.json
    local outputBase = graphPath .. "_out"
    self.outputPath = string.format("%s/%s/event_frame_mapping.json", outputBase, storyId)

    return self.outputPath
end

--- Process pending updates for current frame
--- Assigns frame IDs to events with pending start/end updates
--- Returns true if any updates were made
---
--- @param frameId number The current frame number
--- @return boolean True if any events were updated
function EventFrameMappingCollector:processPendingUpdates(frameId)
    local hasUpdates = false

    for eventId, pending in pairs(self.pendingUpdates) do
        local event = self.events[eventId]

        -- Assign start frame if pending
        if pending.pendingStart and event.startFrame == nil then
            event.startFrame = frameId
            pending.pendingStart = false
            hasUpdates = true

            if DEBUG then
                print(string.format("[EventFrameMappingCollector] Event %s started at frame %d",
                    eventId, frameId))
            end
        end

        -- Assign end frame if pending
        if pending.pendingEnd and event.endFrame == nil then
            event.endFrame = frameId
            pending.pendingEnd = false
            hasUpdates = true

            if DEBUG then
                print(string.format("[EventFrameMappingCollector] Event %s ended at frame %d",
                    eventId, frameId))
            end
        end

        -- Clean up if no more pending updates
        if not pending.pendingStart and not pending.pendingEnd then
            self.pendingUpdates[eventId] = nil
        end
    end

    return hasUpdates
end

--- Write all events to JSON file
--- Overwrites the file with all events (including incomplete ones)
--- This ensures no data loss if the process crashes
---
--- @param storyId string The story ID
--- @return boolean Success
function EventFrameMappingCollector:writeToFile(storyId)
    local outputPath = self:getOutputPath(storyId)

    -- Convert events table to array
    local eventsArray = {}
    for eventId, event in pairs(self.events) do
        table.insert(eventsArray, {
            eventId = event.eventId,
            startFrame = event.startFrame,
            endFrame = event.endFrame
        })
    end

    -- Build output structure
    local output = {
        fps = self.fps,
        events = eventsArray
    }

    -- Convert to JSON
    local jsonStr = toJSON(output, true)  -- true = pretty print

    if not jsonStr then
        print("[EventFrameMappingCollector] ERROR: Failed to serialize events to JSON")
        return false
    end

    -- Write to file
    local file = fileCreate(outputPath)
    if not file then
        print("[EventFrameMappingCollector] ERROR: Failed to create file: " .. outputPath)
        return false
    end

    fileWrite(file, jsonStr)
    fileClose(file)

    if DEBUG then
        print(string.format("[EventFrameMappingCollector] Wrote %d events to: %s",
            #eventsArray, outputPath))
    end

    return true
end

--- Collect and save event frame mapping
--- Processes pending updates for current frame and writes to JSON immediately
--- Writes on EVERY frame with updates to prevent data loss
---
--- @param frameContext table Current frame context data
--- @param frameId number Sequential frame number
--- @param callback function Completion callback: callback(success)
function EventFrameMappingCollector:collectAndSave(frameContext, frameId, callback)
    local storyId = frameContext.storyId or self.config.storyId

    if not storyId then
        if DEBUG then
            print("[EventFrameMappingCollector] WARNING: StoryId not available, skipping frame " .. frameId)
        end
        if callback then
            callback(true)  -- Don't fail the collection cycle
        end
        return
    end

    -- Process any pending updates for this frame
    local hasUpdates = self:processPendingUpdates(frameId)

    -- Write to file immediately if there were any updates
    if hasUpdates then
        local success = self:writeToFile(storyId)

        if not success then
            print("[EventFrameMappingCollector] WARNING: Failed to write event mapping for frame " .. frameId)
        end
    end

    -- Always succeed - don't block other collectors
    if callback then
        callback(true)
    end
end

--- Stop collection and write final event mapping
--- Final write of all events (including incomplete ones with nil frames)
function EventFrameMappingCollector:stopCollection()
    if DEBUG then
        print("[EventFrameMappingCollector] Stopping collection...")
    end

    -- Final write of all events
    local storyId = self.config.storyId
    if storyId then
        local eventCount = 0
        for _ in pairs(self.events) do
            eventCount = eventCount + 1
        end

        if eventCount > 0 then
            self:writeToFile(storyId)

            if DEBUG then
                print(string.format("[EventFrameMappingCollector] Final write: %d events", eventCount))
            end
        end
    end

    -- Unsubscribe from events
    local eventBus = EventBus:getInstance()
    eventBus:unsubscribe("graph_event_start", "event_frame_mapper")
    eventBus:unsubscribe("graph_event_end", "event_frame_mapper")

    if DEBUG then
        print("[EventFrameMappingCollector] Unsubscribed from EventBus")
    end
end

--- Get collector information
--- @return table Table with collector details
function EventFrameMappingCollector:getInfo()
    local eventCount = 0
    for _ in pairs(self.events) do
        eventCount = eventCount + 1
    end

    local pendingCount = 0
    for _ in pairs(self.pendingUpdates) do
        pendingCount = pendingCount + 1
    end

    return {
        name = self.name,
        enabled = self.enabled,
        fps = self.fps,
        totalEvents = eventCount,
        pendingUpdates = pendingCount,
        outputPath = self.outputPath
    }
end
