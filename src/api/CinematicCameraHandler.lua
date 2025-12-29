--- Cinematic camera handler with graph-driven control using semantic commands
--- Camera behavior controlled explicitly by graph events using filmmaker vocabulary
--- No automatic focus switching - camera only moves on graph event commands
--- @class CinematicCameraHandler
CinematicCameraHandler = class(CameraHandlerBase, function(o)
    CameraHandlerBase.init(o)
    o.trackingTimer = nil
    o.currentActor = nil
    o.currentShotMode = nil  -- Track "continuous" or "fixed" mode for subject-based focus filtering
    o.trackedRegion = nil  -- Track region for continuous tracking validation
    o.lastCameraPos = nil  -- For smooth position interpolation (layer 2)
    o.lastConstrainedPos = nil  -- For smooth boundary constraint adjustments (layer 1)
    o.lastLookAtPos = nil  -- For smooth rotation/look-at target (layer 3)
    o.validationCounter = 0  -- Throttle validation requests
end)

--- Reset camera handler state
--- Cleans up both custom timer-based tracking and built-in camera following
function CinematicCameraHandler:Reset()
    CameraHandlerBase.Reset(self)

    -- Stop custom timer-based tracking
    if self.trackingTimer then
        self.trackingTimer:destroy()
        self.trackingTimer = nil
    end

    self.currentActor = nil
    self.currentShotMode = nil
    self.trackedRegion = nil
end

--- Initialize cinematic camera handler with initial fade-in
--- Overrides base to fade in camera at story start
--- @param hasCameraSection boolean Whether graph has camera section
function CinematicCameraHandler:initialize(hasCameraSection)
    -- Call base initialization first
    CameraHandlerBase.initialize(self, hasCameraSection)

    -- Fade in camera at story start (if camera commands present)
    if hasCameraSection then
        if DEBUG then
            print("[CinematicCameraHandler] Fading in camera at story start")
        end

        -- Fade in after short delay to ensure spectators are ready
        -- Note: Interior is NOT set here - it will be set when recording starts
        -- based on the actor's region, or when context/region changes
        Timer(function()
            for _, spectator in ipairs(CURRENT_STORY.Spectators) do
                spectator:setData('fadedCamera', true)
                spectator:fadeCamera(true, 0)

                -- Enable MTA's built-in camera collision (test feature)
                triggerClientEvent(spectator, "sv2l:enableCameraClip", spectator)
            end

            if DEBUG_CAMERA then
                print("[CinematicCameraHandler] Requested client to enable MTA camera collision")
            end
        end, 500, 1)  -- 500ms delay, then fade in
    end
end

--- Override: Execute camera command with interior setting on recording start
--- Sets spectator interior based on actor's region when recording begins
--- @param cameraCmd table Camera command from graph
--- @param eventData table Event context {eventId, actorId, actionName}
function CinematicCameraHandler:executeCommand(cameraCmd, eventData)
    -- Call base implementation first (handles recording control)
    CameraHandlerBase.executeCommand(self, cameraCmd, eventData)

    -- Set spectator interior when recording starts
    if cameraCmd.recording == "start" then
        local actor = self:getActor(eventData.actorId)
        if actor then
            local regionId = self:getCurrentRegionAndEpisode(actor)
            local region = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r) return r.Id == regionId end)

            if region and region.Episode then
                if DEBUG_CAMERA then
                    print("[CinematicCameraHandler] Setting spectator interior on recording start: "..region.Episode.name.." (interior "..region.Episode.InteriorId..")")
                end
                self:setSpectatorInterior(region.Episode)
            else
                if DEBUG then
                    print("[CinematicCameraHandler] Warning: Could not find region/episode for actor "..eventData.actorId.." to set interior")
                end
            end
        end
    end
end

--- Execute shot command (camera positioning) for cinematic mode
--- Overrides base implementation to handle cinematic-specific shots
--- Sets focused actor and updates spectator interior to match (event-driven, no timer)
--- @param shotSpec table Shot specification {type, subject, target, ...}
--- @param eventData table Event context {eventId, actorId, actionName}
function CinematicCameraHandler:executeShot(shotSpec, eventData)
    -- Parse semantic command (wrap in shot structure for parser)
    local semanticSpec = CameraSpecParser.Parse({shot = shotSpec})

    -- Translate to technical parameters
    local technicalParams = CameraParameters.Translate(semanticSpec)

    -- Track shot mode for subject-based focus filtering
    -- "fixed" shots (static, closeup, etc.) only allow subject to update spectator interior
    -- "continuous" shots (follow) allow all actors to update spectator interior
    self.currentShotMode = technicalParams.mode

    if DEBUG then
        print("[CinematicCameraHandler] Executing "..semanticSpec.type.." shot for event "..eventData.eventId)
    end

    -- Get the subject of this shot (works for ALL shot types)
    local subject = self:getEntity(technicalParams.subject or eventData.actorId, eventData)

    if subject then
        -- Track this actor as currently focused by camera
        self.currentActor = subject

        -- Set spectator interior to match focused actor's interior
        -- The spectator IS the cameraman - wherever spectator is, camera is
        if subject.interior ~= nil then
            for _, spectator in ipairs(CURRENT_STORY.Spectators) do
                spectator.interior = subject.interior
            end

            if DEBUG_CAMERA then
                print("[CinematicCameraHandler] Camera focused on "..(technicalParams.subject or eventData.actorId).." - set spectator interior to "..subject.interior)
            end
        end
    end

    -- Execute based on behavior
    if technicalParams.behavior == "track_behind" then
        self:startContinuousTracking(technicalParams, eventData)
    elseif technicalParams.behavior == "use_region_camera" then
        self:useRegionCamera(eventData.actorId)
    elseif technicalParams.behavior == "focus_on_subject" then
        self:focusOnSubject(technicalParams, eventData)
    elseif technicalParams.behavior == "look_at_target" then
        self:overShoulderShot(technicalParams, eventData)
    elseif technicalParams.behavior == "frame_multiple" then
        self:frameTwoShot(technicalParams, eventData)
    elseif technicalParams.behavior == "no_change" then
        -- Free camera: do nothing
        if DEBUG then
            print("[CinematicCameraHandler] Free camera - no change")
        end
    else
        if DEBUG then
            print("[CinematicCameraHandler] Unknown behavior: "..technicalParams.behavior)
        end
    end
end

--- Start continuous tracking of a subject (e.g., "follow actor0")
--- Branches to either built-in MTA camera following or custom timer-based implementation
--- based on USE_BUILTIN_CAMERA_FOLLOW global flag
--- @param params table Technical parameters from translation
--- @param eventData table Event context
function CinematicCameraHandler:startContinuousTracking(params, eventData)
    -- Stop previous tracking
    if self.trackingTimer then
        self.trackingTimer:destroy()
        self.trackingTimer = nil
    end

    local actor = self:getActor(params.subject or eventData.actorId)
    if not actor then
        print("[CinematicCameraHandler] Cannot track - actor not found: "..(params.subject or eventData.actorId))
        return
    end

    self.currentActor = actor
    self.trackedRegion = self:getRegionForEntity(actor)

    if DEBUG then
        print("[CinematicCameraHandler] Starting continuous tracking of "..(params.subject or eventData.actorId))
    end

    -- Branch based on feature flag
    if USE_BUILTIN_CAMERA_FOLLOW then
        -- Use MTA's built-in camera following (simple, smooth client-side interpolation)
        self:startBuiltinCameraFollow(actor, params)
    else
        -- Use custom timer-based implementation (full control with 3-layer smoothing)
        self:startCustomCameraFollow(actor, params)
    end
end

--- Start camera following using MTA's built-in setCameraTarget
--- Provides smooth client-side camera interpolation with minimal server overhead
--- Spectator interior already set by executeShot, context switches handled by requestFocus
--- @param actor table Actor ped to follow
--- @param params table Technical camera parameters for initial positioning
function CinematicCameraHandler:startBuiltinCameraFollow(actor, params)
    if DEBUG_CAMERA then
        print("[CinematicCameraHandler] Using built-in MTA camera following (client-side setCameraTarget)")
    end

    -- Calculate initial camera position behind the actor for clean transition
    local actorPos = actor.position
    local actorRot = actor.rotation or Vector3(0, 0, 0)

    local forward = Vector3(
        math.cos(math.rad(actorRot.z)),
        math.sin(math.rad(actorRot.z)),
        0
    )
    forward:normalize()

    -- Position camera behind actor at proper distance and height
    local initialCameraPos = actorPos
        - forward * params.distance
        + Vector3(params.offset.x, params.offset.y, params.offset.z)

    -- Look-at target (chest level for 1m tall actors)
    local lookAtPos = actorPos + Vector3(0, 0, 0.6)

    -- Trigger client-side camera setup for all spectators
    -- Client passes: actor, initial position, and look-at for clean transition
    for _, spectator in ipairs(CURRENT_STORY.Spectators) do
        triggerClientEvent(spectator, "sv2l:startCameraFollow", spectator, {
            actor = actor,
            initialPos = initialCameraPos,
            initialLookAt = lookAtPos
        })
    end

    -- NOTE: No timer needed - spectator interior already set by executeShot when camera focused on actor
    -- Context switches will trigger requestFocus() which updates spectator interior event-driven
end

--- Start camera following using custom timer-based implementation
--- Provides full control over camera positioning with 3-layer smoothing:
--- - Layer 1: Constraint smoothing (0.6 lerp) for boundary adjustments
--- - Layer 2: Position smoothing (0.5 lerp) for camera motion
--- - Layer 3: Look-at smoothing (0.7 lerp) for rotation
--- @param actor table Actor ped to follow
--- @param params table Technical camera parameters
function CinematicCameraHandler:startCustomCameraFollow(actor, params)
    -- Reset smoothing state for new tracking session
    self.lastCameraPos = nil  -- Reset smoothing for new tracking (layer 2)
    self.lastConstrainedPos = nil  -- Reset constraint smoothing for new tracking (layer 1)
    self.lastLookAtPos = nil  -- Reset look-at smoothing for new tracking (layer 3)
    self.validationCounter = 0  -- Reset throttle counter

    if DEBUG_CAMERA then
        print("[CinematicCameraHandler] Using custom timer-based camera following (setCameraMatrix + smoothing)")
    end

    -- Update camera every 25ms with validation
    self.trackingTimer = Timer(function()
        if not actor or not actor.position then
            if DEBUG_CAMERA then
                print("[CinematicCameraHandler] Actor no longer valid, stopping tracking")
            end
            return
        end

        -- Detect region changes
        local regionChanged, currentRegion = CameraValidation.hasActorChangedRegion(actor, self.trackedRegion)
        if regionChanged then
            self.trackedRegion = currentRegion
            if DEBUG_CAMERA_VALIDATION then
                print("[CinematicCameraHandler] Actor changed region during tracking: "..(currentRegion and currentRegion.name or "unknown"))
            end

            -- Update spectator interior when actor moves to different region/episode
            if currentRegion and currentRegion.Episode then
                if DEBUG_CAMERA then
                    print("[CinematicCameraHandler] Updating spectator interior for region change: "..currentRegion.Episode.name.." (interior "..currentRegion.Episode.InteriorId..")")
                end
                self:setSpectatorInterior(currentRegion.Episode)
            end
        end

        -- Calculate ideal camera position (region-aware: ensures position stays within bounds)
        local idealCameraPos = self:calculateCameraPosition(actor, params, self.trackedRegion)

        -- Calculate ideal look-at position (chest level for 1m actors)
        local idealLookAtPos = actor.position + Vector3(0, 0, 0.6)

        -- Smooth interpolation (lerp) toward ideal position (layer 2)
        local smoothedCameraPos
        if self.lastCameraPos then
            -- Lerp 50% toward new position each frame for responsive motion
            local lerpFactor = 0.5
            smoothedCameraPos = self.lastCameraPos + (idealCameraPos - self.lastCameraPos) * lerpFactor
        else
            smoothedCameraPos = idealCameraPos  -- First frame, no smoothing
        end
        self.lastCameraPos = smoothedCameraPos

        -- Smooth look-at target to prevent jittery rotation (layer 3)
        local smoothedLookAtPos
        if self.lastLookAtPos then
            -- Lerp 70% toward new look-at target (more aggressive for responsive rotation)
            local lookAtLerpFactor = 0.7
            smoothedLookAtPos = self.lastLookAtPos + (idealLookAtPos - self.lastLookAtPos) * lookAtLerpFactor
        else
            smoothedLookAtPos = idealLookAtPos  -- First frame, no smoothing
        end
        self.lastLookAtPos = smoothedLookAtPos

        -- Apply smoothed position and look-at for stable camera
        for _, spectator in ipairs(CURRENT_STORY.Spectators) do
            spectator:setCameraMatrix(
                smoothedCameraPos.x, smoothedCameraPos.y, smoothedCameraPos.z,
                smoothedLookAtPos.x, smoothedLookAtPos.y, smoothedLookAtPos.z,
                0, -- roll
                params.fov
            )
        end

        -- Throttle validation: only every 500ms (20 frames × 25ms) to reduce flickering
        self.validationCounter = self.validationCounter + 1

        if self.validationCounter >= 20 then
            self.validationCounter = 0

            -- Request async validation (correction will be applied when response arrives)
            CameraValidation.validateCameraPositionAsync(
                smoothedCameraPos,  -- Validate smoothed position, not ideal
                actor.position,
                self.trackedRegion,
                params,
                {
                    checkLineOfSight = true,
                    checkRegionBounds = true,
                    strategy = "incremental",  -- Best for continuous follow shots
                    maxAttempts = 10
                },
                function(result)
                    -- Callback: apply all validation corrections to respect region boundaries
                    if result.adjustmentMade and result.finalCameraPos then
                        local correctedPos = Vector3(result.finalCameraPos.x, result.finalCameraPos.y, result.finalCameraPos.z)
                        local currentPos = self.lastCameraPos or smoothedCameraPos
                        local distance = (correctedPos - currentPos):getLength()

                        -- Apply correction to keep camera within region bounds
                        self.lastCameraPos = correctedPos
                        if DEBUG_CAMERA_VALIDATION then
                            print("[CinematicCameraHandler] Correction applied: "..string.format("%.2f", distance).." units")
                        end
                    end
                end
            )
        end
    end, 25, 0) -- Every 25ms (40 FPS), infinite repeats
end

--- One-time camera positioning focused on a subject (e.g., "close up on object0", "show actor0")
--- @param params table Technical parameters from translation
--- @param eventData table Event context
function CinematicCameraHandler:focusOnSubject(params, eventData)
    local subject = self:getEntity(params.subject or eventData.actorId, eventData)
    if not subject then
        print("[CinematicCameraHandler] Cannot focus - subject not found: "..(params.subject or eventData.actorId))
        return
    end

    if DEBUG then
        print("[CinematicCameraHandler] Focusing on subject: "..(params.subject or eventData.actorId))
    end

    -- Get region for boundary checking
    local region = self:getRegionForEntity(subject)

    -- Calculate camera position (region-aware: ensures position stays within bounds)
    local idealCameraPos = self:calculateCameraPosition(subject, params, region)
    local lookAtPos = subject.position + Vector3(0, 0, params.height or 1)

    -- Apply ideal position immediately
    for _, spectator in ipairs(CURRENT_STORY.Spectators) do
        spectator:setCameraMatrix(
            idealCameraPos.x, idealCameraPos.y, idealCameraPos.z,
            lookAtPos.x, lookAtPos.y, lookAtPos.z,
            0, -- roll
            params.fov
        )
    end

    -- Request async validation
    CameraValidation.validateCameraPositionAsync(
        idealCameraPos,
        subject.position,
        region,
        params,
        {
            checkLineOfSight = true,
            checkRegionBounds = true,
            strategy = "incremental",
            maxAttempts = 10
        },
        function(result)
            -- Callback: apply correction if needed
            if result.adjustmentMade and result.finalCameraPos then
                local correctedPos = result.finalCameraPos
                for _, spectator in ipairs(CURRENT_STORY.Spectators) do
                    spectator:setCameraMatrix(
                        correctedPos.x, correctedPos.y, correctedPos.z,
                        lookAtPos.x, lookAtPos.y, lookAtPos.z,
                        0, -- roll
                        params.fov
                    )
                end
            end
        end
    )
end

--- Over-shoulder shot looking from subject to target
--- @param params table Technical parameters
--- @param eventData table Event context
function CinematicCameraHandler:overShoulderShot(params, eventData)
    local subject = self:getEntity(params.subject or eventData.actorId, eventData)
    local target = self:getEntity(params.target, eventData)

    if not subject or not target then
        print("[CinematicCameraHandler] Over-shoulder shot requires both subject and target")
        return
    end

    -- Position camera behind subject's shoulder
    local subjectPos = subject.position
    local targetPos = target.position

    -- Direction from subject to target
    local directionToTarget = (targetPos - subjectPos):getNormalized()

    -- Camera position: behind and to the side of subject
    local idealCameraPos = subjectPos - directionToTarget * params.offset.y + Vector3(params.offset.x, 0, params.offset.z)

    -- Look at target
    local lookAtPos = targetPos + Vector3(0, 0, params.height or 1)

    -- Apply ideal position immediately
    for _, spectator in ipairs(CURRENT_STORY.Spectators) do
        spectator:setCameraMatrix(
            idealCameraPos.x, idealCameraPos.y, idealCameraPos.z,
            lookAtPos.x, lookAtPos.y, lookAtPos.z,
            0,
            params.fov
        )
    end

    -- Request async validation
    local region = self:getRegionForEntity(subject)
    CameraValidation.validateCameraPositionAsync(
        idealCameraPos,
        targetPos,
        region,
        params,
        {
            checkLineOfSight = true,
            checkRegionBounds = true,
            strategy = "slide",  -- Slide along wall is better for over-shoulder shots
            maxAttempts = 10
        },
        function(result)
            -- Callback: apply correction if needed
            if result.adjustmentMade and result.finalCameraPos then
                local correctedPos = result.finalCameraPos
                for _, spectator in ipairs(CURRENT_STORY.Spectators) do
                    spectator:setCameraMatrix(
                        correctedPos.x, correctedPos.y, correctedPos.z,
                        lookAtPos.x, lookAtPos.y, lookAtPos.z,
                        0,
                        params.fov
                    )
                end
            end
        end
    )
end

--- Two-shot framing multiple subjects
--- @param params table Technical parameters
--- @param eventData table Event context
function CinematicCameraHandler:frameTwoShot(params, eventData)
    if not params.subjects or #params.subjects < 2 then
        print("[CinematicCameraHandler] Two-shot requires at least 2 subjects")
        return
    end

    -- Get all subjects
    local entities = {}
    for _, subjectId in ipairs(params.subjects) do
        local entity = self:getEntity(subjectId, eventData)
        if entity then
            table.insert(entities, entity)
        end
    end

    if #entities < 2 then
        print("[CinematicCameraHandler] Could not find enough subjects for two-shot")
        return
    end

    -- Calculate center point between subjects
    local centerPos = Vector3(0, 0, 0)
    for _, entity in ipairs(entities) do
        centerPos = centerPos + entity.position
    end
    centerPos = centerPos / #entities

    -- Position camera to frame all subjects
    local idealCameraPos = centerPos + Vector3(params.offset.x, params.offset.y, params.offset.z)
    local lookAtPos = centerPos + Vector3(0, 0, params.height or 1)

    -- Apply ideal position immediately
    for _, spectator in ipairs(CURRENT_STORY.Spectators) do
        spectator:setCameraMatrix(
            idealCameraPos.x, idealCameraPos.y, idealCameraPos.z,
            lookAtPos.x, lookAtPos.y, lookAtPos.z,
            0,
            params.fov
        )
    end

    -- Request async validation (use first entity's region)
    local region = self:getRegionForEntity(entities[1])
    CameraValidation.validateCameraPositionAsync(
        idealCameraPos,
        centerPos,
        region,
        params,
        {
            checkLineOfSight = true,
            checkRegionBounds = true,
            strategy = "rotate",  -- Rotate around center to find clear view of all subjects
            maxAttempts = 12
        },
        function(result)
            -- Callback: apply correction if needed
            if result.adjustmentMade and result.finalCameraPos then
                local correctedPos = result.finalCameraPos
                for _, spectator in ipairs(CURRENT_STORY.Spectators) do
                    spectator:setCameraMatrix(
                        correctedPos.x, correctedPos.y, correctedPos.z,
                        lookAtPos.x, lookAtPos.y, lookAtPos.z,
                        0,
                        params.fov
                    )
                end
            end
        end
    )
end

--- Use region's static camera (semantic command: "static")
--- @param actorId string Actor ID to use for region lookup
function CinematicCameraHandler:useRegionCamera(actorId)
    local actor = self:getActor(actorId)
    if not actor then
        print("[CinematicCameraHandler] Cannot use region camera - actor not found: "..actorId)
        return
    end

    local regionId, regionName, episodeName = self:getCurrentRegionAndEpisode(actor)
    local region = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r) return r.Id == regionId end)

    if region then
        if DEBUG then
            print("[CinematicCameraHandler] Using static camera for region: "..region.name)
        end
        region:SetStaticCameraWhereActorIsInFOVOrRandom(actor)
    else
        print("[CinematicCameraHandler] Could not find region for static camera")
    end
end

--- Calculate camera position relative to subject using technical parameters
--- Region-aware: ensures camera position stays within region boundaries
--- @param subject table Entity with position and rotation
--- @param params table Technical parameters {distance, offset, ...}
--- @param region Region|nil Optional region to constrain camera position within bounds
--- @return table Vector3 camera position (guaranteed inside region if provided)
function CinematicCameraHandler:calculateCameraPosition(subject, params, region)
    local subjectPos = subject.position
    local subjectRot = subject.rotation or Vector3(0, 0, 0)

    -- Calculate forward direction from rotation
    local forward = Vector3(
        math.cos(math.rad(subjectRot.z)),
        math.sin(math.rad(subjectRot.z)),
        0
    )
    forward:normalize()

    -- Calculate ideal camera position: behind subject at specified distance + offset
    -- Fixed: Use 0.8 units (eye level for 1m tall actors), not offset.z + height
    local idealCameraPos = subjectPos
        - forward * params.distance
        + Vector3(params.offset.x, params.offset.y, 0.8)

    -- If region provided, ensure camera stays within region bounds
    if region then
        if not region:IsPointInside2(idealCameraPos) then
            if DEBUG_CAMERA then
                print("[CinematicCameraHandler] Ideal camera position outside region, finding valid position")
            end

            -- Try progressively closer positions with finer 2% increments: 98%, 96%, 94%...
            -- Finer granularity reduces visible jumps (2% = 0.1 units for 5 unit distance)
            local validPos = nil
            for distancePercent = 98, 10, -2 do
                local testDistance = params.distance * (distancePercent / 100)
                local testPos = subjectPos
                    - forward * testDistance
                    + Vector3(params.offset.x, params.offset.y, 0.8)

                if region:IsPointInside2(testPos) then
                    validPos = testPos
                    if DEBUG_CAMERA then
                        print("[CinematicCameraHandler] Found valid position at "..distancePercent.."% of distance")
                    end
                    break
                end
            end

            -- Apply constraint smoothing layer to prevent discrete jumps
            -- Smooths transitions between constrained positions (e.g., 60% → 62% → 64%)
            if validPos then
                if self.lastConstrainedPos then
                    -- Lerp toward new constrained position (layer 1 smoothing)
                    local constraintLerpFactor = 0.6  -- More aggressive for faster boundary adjustment
                    idealCameraPos = self.lastConstrainedPos + (validPos - self.lastConstrainedPos) * constraintLerpFactor
                else
                    -- First constraint, no previous position to smooth from
                    idealCameraPos = validPos
                end
                -- Store constrained position for next frame's smoothing
                self.lastConstrainedPos = idealCameraPos
            else
                -- No valid position found, clamp to actor position + small offset
                idealCameraPos = subjectPos + Vector3(0, 0, 0.8)
                self.lastConstrainedPos = idealCameraPos
            end
        else
            -- Ideal position is inside region, no constraint needed
            -- Update lastConstrainedPos for smooth transition when constraint becomes active
            self.lastConstrainedPos = idealCameraPos
        end
    end

    return idealCameraPos
end

--- Get actor by ID
--- @param actorId string Actor identifier
--- @return table|nil Actor ped or nil if not found
function CinematicCameraHandler:getActor(actorId)
    if not actorId then return nil end

    return FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped)
        return ped:getData('id') == actorId
    end)
end

--- Get entity (actor, object, or region) by ID
--- @param entityId string Entity identifier
--- @param eventData table Event context for additional lookup
--- @return table|nil Entity or nil if not found
function CinematicCameraHandler:getEntity(entityId, eventData)
    if not entityId then return nil end

    -- Try as actor first
    local actor = self:getActor(entityId)
    if actor then return actor end

    -- Try as object
    local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(obj)
        return obj.ObjectId == entityId or obj.id == entityId
    end)
    if object then return object end

    -- Try as region (fuzzy match on Region.name, same as action location matching)
    local region = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r)
        return r.name:lower():find(entityId:lower())
    end)
    if region then
        if DEBUG then
            print("[CinematicCameraHandler] Resolved region: "..entityId.." → "..region.name)
        end
        return {
            position = region.center,
            rotation = Vector3(0, 0, 0)
        }
    end

    if DEBUG then
        print("[CinematicCameraHandler] Could not resolve entity: "..entityId)
    end
    return nil
end

--- Get current region for an actor
--- @param actorId string Actor identifier
--- @return table|nil Region or nil if not found
function CinematicCameraHandler:getCurrentRegion(actorId)
    local actor = self:getActor(actorId)
    if not actor then return nil end

    local regionId = actor:getData('currentRegionId')
    return FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r)
        return r.Id == regionId
    end)
end

--- Get region for any entity (actor, object, or returns nil if entity is a region reference)
--- @param entity table Entity with position (actor ped, object, or region stub)
--- @return table|nil Region or nil if not found
function CinematicCameraHandler:getRegionForEntity(entity)
    if not entity or not entity.position then return nil end

    -- If entity has getData (it's an actor ped), use getCurrentRegion logic
    if entity.getData then
        local regionId = entity:getData('currentRegionId')
        return FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r)
            return r.Id == regionId
        end)
    end

    -- For objects or generic entities, find region containing the position
    return FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r)
        return r:IsPointInside2(entity.position)
    end)
end

--- Set spectator interior to match episode
--- Required for spectators to see actors/objects in interior environments
--- Matches pattern from Region:SetStaticCamera() for static mode compatibility
--- @param episode table Episode with InteriorId
function CinematicCameraHandler:setSpectatorInterior(episode)
    if not episode or not episode.InteriorId then
        if DEBUG then
            print("[CinematicCameraHandler] Cannot set spectator interior - invalid episode")
        end
        return
    end

    if DEBUG_CAMERA then
        print("[CinematicCameraHandler] Setting spectator interior to "..episode.InteriorId.." ("..episode.name..")")
    end

    for _, spectator in ipairs(CURRENT_STORY.Spectators) do
        spectator.interior = episode.InteriorId
    end
end

--- Stop tracking when event ends
--- @param eventData table Event context
function CinematicCameraHandler:onGraphEventEnd(eventData)
    CameraHandlerBase.onGraphEventEnd(self, eventData)

    if self.trackingTimer then
        if DEBUG then
            print("[CinematicCameraHandler] Stopping tracking at event end: "..eventData.eventId)
        end
        self.trackingTimer:destroy()
        self.trackingTimer = nil
    end
end

--- Override: Handle focus requests for spectator interior updates during context switches
--- Camera positioning is controlled by graph events, but we update spectator interior
--- when the CURRENTLY FOCUSED actor switches context (event-driven, no timer)
--- For fixed shots (static, closeup, etc.), only the subject actor can update spectator interior
--- @param playerId string Actor ID requesting focus
function CinematicCameraHandler:requestFocus(playerId)
    -- For fixed shots (static, closeup, etc.), only the subject actor can update spectator interior
    -- This prevents other actors from pulling the camera view away during static shots
    if self.currentShotMode == "fixed" then
        -- Safety: if no current actor set, allow update
        if not self.currentActor then
            if DEBUG_CAMERA then
                print("[CinematicCameraHandler] No current subject - allowing focus request from "..playerId)
            end
            -- Fall through to normal update
        elseif self.currentActor.getData then
            -- Current actor is a ped - check if it's the requesting actor
            local currentSubjectId = self.currentActor:getData('id')
            if currentSubjectId ~= playerId then
                if DEBUG_CAMERA then
                    print("[CinematicCameraHandler] Fixed shot on "..currentSubjectId.." - ignoring focus request from "..playerId)
                end
                return  -- Block the request
            end
        else
            -- Current actor is an object or region - allow all actor movements
            if DEBUG_CAMERA then
                print("[CinematicCameraHandler] Subject is not an actor - allowing focus request from "..playerId)
            end
            -- Fall through to normal update
        end
    end

    -- Update spectator interior for the requesting actor
    -- The spectator IS the cameraman - wherever spectator is, camera is
    -- This is called from Move.lua when actor changes regions
    local actor = self:getActor(playerId)
    if actor then
        local actorInterior = actor.interior or 0

        for _, spectator in ipairs(CURRENT_STORY.Spectators) do
            spectator.interior = actorInterior
        end

        if DEBUG_CAMERA then
            print("[CinematicCameraHandler] Region change: Set spectator interior to "..actorInterior.." for actor "..playerId)
        end
    end

    -- Note: We do NOT call assignFocusToRegion or change camera positioning
    -- Camera positioning is controlled by graph events only, this just updates interior
end

--- Override: No automatic focus in cinematic mode
function CinematicCameraHandler:autoFocus()
    -- Do nothing - camera changes only on graph events
end

--- Override: Track episode changes but don't set camera automatically
--- @param actor table The actor
--- @param region table The region
--- @param contextChanged boolean Whether context changed
function CinematicCameraHandler:assignFocusToRegion(actor, region, contextChanged)
    if region then
        -- Update episode tracking (needed for context switching)
        CURRENT_STORY.CurrentFocusedEpisode = region.Episode
        CURRENT_STORY.CurrentEpisode.CurrentRegion = region
        self.currentRegion = region

        if DEBUG then
            print("[CinematicCameraHandler] Episode context updated to: "..region.Episode.name)
        end

        -- Set spectator interior to match new episode context
        self:setSpectatorInterior(region.Episode)

        -- Handle context switching (fade, pause/resume)
        if contextChanged then
            CURRENT_STORY.CurrentFocusedEpisode:Resume()
            self:FadeForAll(true, 1500)
        end

        -- DO NOT call region:AssignFocus(actor) - that would set static camera
        -- Camera position is controlled by graph events only
    end
end

--- Override: No-op methods for focus management (not used in cinematic mode)
function CinematicCameraHandler:freeFocus(playerId)
    -- Do nothing
end

function CinematicCameraHandler:clearFocusRequests(playerId)
    -- Do nothing
end

function CinematicCameraHandler:updatePerspective(playerId)
    -- Do nothing
end

function CinematicCameraHandler:focusTimeReached(playerId, contextChanged)
    -- Do nothing
end
