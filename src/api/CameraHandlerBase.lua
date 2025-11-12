--- Base class for camera handlers providing common functionality
--- Subclasses implement specific camera control strategies (static vs cinematic)
--- @class CameraHandlerBase
CameraHandlerBase = class(function(o)
    o.isFocused = false
    o.isSwitchingContext = false

    -- Recording state (defaults to true for backwards compatibility)
    o.isRecording = true
    o.hasCameraCommands = false
end)

--- Reset camera handler state
function CameraHandlerBase:Reset()
    self.isFocused = false
    self.isSwitchingContext = false
end

--- Initialize camera handler with graph camera configuration
--- @param hasCameraSection boolean Whether graph has camera section
function CameraHandlerBase:initialize(hasCameraSection)
    self.hasCameraCommands = hasCameraSection

    if hasCameraSection then
        -- Camera-controlled mode: start in non-recording state
        self.isRecording = false
        if DEBUG then
            print("[CameraHandlerBase] Camera commands enabled, awaiting 'record' command")
        end
    else
        -- Legacy mode: always recording, emit start signal immediately
        self.isRecording = true
        if DEBUG then
            print("[CameraHandlerBase] No camera section, legacy always-on mode")
        end

        -- Emit artifact_start_collection immediately for backwards compatibility
        if CURRENT_STORY.EventBus then
            CURRENT_STORY.EventBus:publish("artifact_start_collection", {
                eventId = "legacy_mode",
                actorId = "system",
                actionName = "legacy_start"
            })
        end
    end

    -- Subscribe to graph events
    if CURRENT_STORY.EventBus then
        CURRENT_STORY.EventBus:subscribe("graph_event_start", "camera_handler", function(eventData)
            self:onGraphEventStart(eventData)
        end)

        CURRENT_STORY.EventBus:subscribe("graph_event_end", "camera_handler", function(eventData)
            self:onGraphEventEnd(eventData)
        end)
    end
end

--- Handle graph event start
--- CameraHandler reads the graph directly to interpret camera commands
--- @param eventData table {eventId, actorId, actionName}
function CameraHandlerBase:onGraphEventStart(eventData)
    if DEBUG then
        print("[CameraHandlerBase] Event start: "..eventData.eventId.." - "..eventData.actionName.." (actor: "..eventData.actorId..")")
    end

    -- Look up camera command in graph (CameraHandler interprets the graph itself)
    if CURRENT_STORY.camera and CURRENT_STORY.camera[eventData.eventId] then
        local cameraCmd = CURRENT_STORY.camera[eventData.eventId]
        self:executeCommand(cameraCmd, eventData)
    end
end

--- Handle graph event end
--- @param eventData table {eventId, actorId, actionName}
function CameraHandlerBase:onGraphEventEnd(eventData)
    if DEBUG then
        print("[CameraHandlerBase] Event end: "..eventData.eventId.." - "..eventData.actionName)
    end
    -- Subclasses can override to handle event-end camera logic
end

--- Execute camera command from graph
--- Handles both recording control and shot control independently
--- @param cameraCmd table Camera command from graph
--- @param eventData table Event context {eventId, actorId, actionName}
function CameraHandlerBase:executeCommand(cameraCmd, eventData)
    -- Handle recording control (independent of shot)
    if cameraCmd.recording then
        if cameraCmd.recording == "start" then
            if DEBUG then
                print("[CameraHandlerBase] Starting recording for event "..eventData.eventId)
            end
            self.isRecording = true

            -- Notify artifact collection to start
            if CURRENT_STORY.EventBus then
                CURRENT_STORY.EventBus:publish("artifact_start_collection", eventData)
            end

        elseif cameraCmd.recording == "stop" then
            if DEBUG then
                print("[CameraHandlerBase] Stopping recording for event "..eventData.eventId)
            end
            self.isRecording = false

            -- Notify artifact collection to stop
            if CURRENT_STORY.EventBus then
                CURRENT_STORY.EventBus:publish("artifact_stop_collection", eventData)
            end
        end
    end

    -- Handle shot control (independent of recording)
    if cameraCmd.shot then
        self:executeShot(cameraCmd.shot, eventData)
    end

    -- Legacy support: {action: "record"} or {action: "stop"}
    if cameraCmd.action then
        if cameraCmd.action == "record" then
            return self:executeCommand({recording = "start"}, eventData)
        elseif cameraCmd.action == "stop" then
            return self:executeCommand({recording = "stop"}, eventData)
        end
    end
end

--- Execute shot command (camera positioning)
--- Base implementation does nothing - subclasses override for mode-specific behavior
--- @param shotSpec table Shot specification {type, subject, target, ...}
--- @param eventData table Event context
function CameraHandlerBase:executeShot(shotSpec, eventData)
    -- Default: do nothing
    -- StaticCameraHandler: may ignore shots
    -- CinematicCameraHandler: implements shot logic
end

--- Check if currently recording (for Move action teleportation)
--- @return boolean True if recording active
function CameraHandlerBase:isCurrentlyRecording()
    return self.isRecording
end

--- Fade camera for all spectators
--- @param fade boolean True to fade in, false to fade out
--- @param time number Fade duration in milliseconds (default 1000)
function CameraHandlerBase:FadeForAll(fade, time)
    if not time then
        time = 1000
    end
    Timer(function(fade)
        for _, spectator in ipairs(CURRENT_STORY.Spectators) do
            spectator:setData('fadedCamera', fade)
            spectator:fadeCamera(fade)
        end
    end, time, 1, fade)
end

--- Gets the current region of a given actor.
--- @param actor table The actor whose current region and episode is to be retrieved.
--- The function first retrieves the regionId, regionName, and episodeName from the actor's data.
--- If any of these data points are not set, the function attempts to fix this by triggering a region hit from the closest point of interest (POI) with respect to the actor.
--- If a closest POI is found, it triggers a region hit for the actor and updates the regionId, regionName, and episodeName.
--- The function then returns the regionId, regionName, and episodeName.
--- @usage local regionId, regionName, episodeName = CameraHandlerBase:getCurrentRegionAndEpisode(actor)
--- @return integer|nil regionid, string|nil regionName, string|nil episodeName The id and name of the region, and the name of the episode the actor is currently in.
function CameraHandlerBase:getCurrentRegionAndEpisode(actor)
    local regionId = actor:getData('currentRegionId')
    local regionName = actor:getData('currentRegion')
    local episodeName = actor:getData('currentEpisode')

    -- if the actor does not yet have a region assigned, try to fix it by triggering a region hit from the closest POI
    if not regionId or not regionName or not episodeName then
        print('[CameraHandlerBase] Trying to fix the actor '..actor:getData('id'))
        local closestPoi = nil
        local minDist = 99999
        for _, poi in ipairs(CURRENT_STORY.CurrentEpisode.POI) do
            if poi.Region then
                local distance = math.abs((poi.position - actor.position).length)
                if distance < minDist then
                    closestPoi = poi
                    minDist = distance
                end
            end
        end
        if closestPoi == nil then
            return regionId, regionName, episodeName
        end
        closestPoi.Region:OnPlayerHit(actor)
        regionId = actor:getData('currentRegionId')
        regionName = actor:getData('currentRegion')
        episodeName = actor:getData('currentEpisode')
    end

    return regionId, regionName, episodeName
end

--- Switches the interior of picked objects in a given region for a specific actor.
--- @param actor any The actor who has picked the objects.
--- @param region table The region where the objects are located.
--- The function first retrieves the picked objects from the actor's data.
--- If the region and picked objects exist, it iterates over each picked object.
--- For each object, it finds the corresponding object in the current episode's objects.
--- If the object instance is found, it switches the interior to the interior of the given region's episode.
--- @usage CameraHandlerBase:switchPickedObjectsInterior(actor, region)
function CameraHandlerBase:switchPickedObjectsInterior(actor, region)
    local pickedObjects = actor:getData('pickedObjects')
    if region and pickedObjects then
        for _, o in ipairs(pickedObjects) do
            print("Switching interior for object "..o[1])
            local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(obj) return obj.ObjectId == o[1] end)
            if object and object.instance then
                print("Found object instance, switching to interior "..region.Episode.InteriorId..' of episode '..region.Episode.name)
                object.instance.interior = region.Episode.InteriorId
            end
        end
    end
end

--- Wait until the old episode is paused, then assign focus to the new region
--- Used during context switching to ensure clean episode transitions
--- @param playerId string The id of the player to assign focus to
--- @param regionId integer The id of the region to assign focus to
--- @param contextChanged boolean Whether the context has changed
--- @param unfaded boolean Whether the camera has been unfaded (internal use)
--- @param maxWaitTime number Maximum time to wait for pause (default 30000ms)
function CameraHandlerBase:WaitUntilEpisodePausedThenAssignFocusToRegion(playerId, regionId, contextChanged, unfaded, maxWaitTime)
    if not maxWaitTime then
        maxWaitTime = 30000
    end
    Timer(function(playerId, regionId, contextChanged, maxWaitTime)
        if not CURRENT_STORY.CurrentFocusedEpisode:AreAllActionsPaused(maxWaitTime <= 0) then
            CURRENT_STORY.CameraHandler:WaitUntilEpisodePausedThenAssignFocusToRegion(playerId, regionId, contextChanged, false, maxWaitTime)
        elseif not unfaded then
            self:FadeForAll(false, 0)
            CURRENT_STORY.CameraHandler:WaitUntilEpisodePausedThenAssignFocusToRegion(playerId, regionId, contextChanged, true)
        else
            CURRENT_STORY.CameraHandler.isSwitchingContext = false
            local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('id') == playerId end)
            local region = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r) return r.Id == regionId end)
            CURRENT_STORY.CameraHandler:assignFocusToRegion(actor, region, contextChanged)
        end
    end, 1000, 1, playerId, regionId, contextChanged, maxWaitTime - 1000)
end

--- String representation for debugging
function CameraHandlerBase:__tostring()
    local isFocusedStr = self.isFocused and 'true' or 'false'
    return '{\n\tisFocused: '..isFocusedStr..'\n\tisRecording: '..tostring(self.isRecording)..'\n\t}'
end
