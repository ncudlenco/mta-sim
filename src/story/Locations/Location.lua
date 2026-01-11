Location = class(StoryLocationBase, function(o, x, y, z, angle, interior, description, region, compact, log, episodeLinks)
    StoryLocationBase.init(o, description, {})
    o.X = x
    o.Y = y
    o.Z = z
    o.Angle = angle
    o.Interior = interior
    o.History = {}
    o.Region = region
    o.isBusy = false
    if not compact then
        o.position = Vector3(x,y,z)
        o.rotation = Vector3(0,0,angle)
    else
        o.position = {x=x, y=y, z=z}
        o.rotation = {x=0, y=0, z=angle}
    end
    o.interactionsOnly = false
    o.allActions = {}
    o.metatable = {}
    o.episodeLinks = episodeLinks or {}
end)

function Location:getData(key)
    if key == nil then
        return nil
    end
    return self.metatable[key]
end

function Location:setData(key, value)
    self.metatable[key] = value
end

function Location:SpawnPlayerHere(player, spectate)
    if not spectate then
        self.isBusy = true
        print('[SpawnPlayerHere] '..player:getData('id')..' Location '..self.Description..' is set to busy')
        player:setData('locationId', self.LocationId)
    end
    local z = self.Z
    if spectate then
        z = self.Z + 20
    end
    player:spawn(self.X, self.Y, z, self.Angle, player.model, self.Interior)
    player:fadeCamera (true)
    player:setData('fadedCamera', true)

    if not STATIC_CAMERA and not spectate then
        player:setCameraTarget(player)
    end
    if DEBUG then
        outputConsole("Location:SpawnPlayerHere")
        print("Location:SpawnPlayerHere")
    end
end

function Location:Serialize(episode, relativePosition, _objects, _locations, _mainPOI, _saveMainPoiRelative)
    local objects = {}
    if _objects then
        objects = _objects
    end
    local locations = {}
    if _locations then
        locations = _locations
    end
    local serializedAllActions = {}
    for _, a in ipairs(self.allActions) do
        if DEBUG then
            print("Serialize:action "..a.id)
        end
        local serializedNextAction = nil
        if a.NextAction then
            if isArray(a.NextAction) then
                serializedNextAction = {}
                for _, na in ipairs(a.NextAction) do
                    table.insert(serializedNextAction, {id = na.id})
                end
            else
                serializedNextAction = { id = a.NextAction.id }
            end
        end
        local targetItemType = 'Object'
        local targetItemId = LastIndexOf(episode.Objects, a.TargetItem)
        if targetItemId < 0 then
            targetItemType = 'Location'
            targetItemId = LastIndexOf(episode.POI, a.TargetItem)
            if targetItemId < 0 then
                targetItemType = 'none'
            end
        end
        local closingAction = nil
        if a.ClosingAction then
            closingAction = {id = a.ClosingAction.id}
        end
        local serializedAction = {
            dynamicString = a:GetDynamicString(),
            id = a.id,
            nextAction = serializedNextAction,
            targetItem = {id = targetItemId, type = targetItemType},
            nextLocation = {id = LastIndexOf(episode.POI, self)},
            closingAction = closingAction,
            isClosingAction = a.IsClosingAction
        }

        if DEBUG then
            print("Serialize:serialized action "..serializedAction.dynamicString)
        end

        table.insert(serializedAllActions, serializedAction)
        local function processLocationDependency(location)
            if not location then
                return
            end
            if DEBUG then
                print("Serialize:process location relative "..location.id)
            end
            local locationCopy = {id = location.id or LastIndexOf(episode.POI, location)}
            --If next location is not myself and next location is not already processed in recursivity
            if
                locationCopy.id ~= LastIndexOf(episode.POI, self)
                and #Where(locations, function (x) return x.id == locationCopy.id end) == 0
                and (not _mainPOI or locationCopy.id ~= LastIndexOf(episode.POI, _mainPOI) )
            then
                local targetItemRelativePosition = Vector3(location.position.x, location.position.y, location.position.z) - relativePosition

                locationCopy = location:Serialize(episode, relativePosition, objects, locations, _mainPOI or self, true)
                -- locationCopy.X = targetItemRelativePosition.x
                -- locationCopy.Y = targetItemRelativePosition.y
                -- locationCopy.Z = targetItemRelativePosition.z
                --This is probably handled in recursivity already
                -- for _,v in ipairs(dependentObjects) do
                --     if #Where(objects, function (x) return x.id == v.id end) == 0 then
                --         table.insert(objects, v)
                --     end
                -- end
                -- for _,v in ipairs(dependentLocations) do
                --     if #Where(locations, function (x) return x.id == v.id end) == 0 then
                --         table.insert(locations, v)
                --     end
                -- end
                if #Where(locations, function (x) return x.id == locationCopy.id end) == 0 then
                    table.insert(locations, locationCopy)
                end
            end
        end
        if a.TargetItem and a.TargetItem.position and relativePosition then
            if targetItemType == 'Object' then
                if DEBUG then
                    outputConsole("Serialize:target object "..targetItemId)
                end

                local objectCopy = SampStoryObjectBase(a.TargetItem)
                local targetItemRelativePosition = Vector3(a.TargetItem.position.x, a.TargetItem.position.y, a.TargetItem.position.z) - relativePosition
                objectCopy.position = targetItemRelativePosition
                objectCopy.instance = nil
                objectCopy:UpdateData(true)
                objectCopy.id = targetItemId
                if #Where(objects, function (x) return x.id == objectCopy.id end) == 0 then
                    table.insert(objects, {
                        id = objectCopy.id,
                        dynamicString = objectCopy.dynamicString
                    })
                end
            elseif targetItemType == 'Location' then
                if DEBUG then
                    print("Serialize:target location "..targetItemId)
                end
                processLocationDependency(a.TargetItem)
            end
        end
        if relativePosition then
            if DEBUG then
                print("Serialize:process location relative")
            end
            processLocationDependency(a.NextLocation)
        end
    end

    local serializedPossibleActions = {}
    for _, a in ipairs(self.PossibleActions) do
        table.insert(serializedPossibleActions, {id = a.id})
    end

    local serializedMainPoi = {
        X = self.X,
        Y = self.Y,
        Z = self.Z,
        Angle = self.Angle,
        Interior = self.Interior,
        Description = self.Description,
        allActions = serializedAllActions,
        PossibleActions = serializedPossibleActions,
        id = LastIndexOf(episode.POI, self),
        episodeLinks = self.episodeLinks
    }
    if _saveMainPoiRelative then
        local targetItemRelativePosition = Vector3(self.X, self.Y, self.Z) - relativePosition
        serializedMainPoi.X = targetItemRelativePosition.x
        serializedMainPoi.Y = targetItemRelativePosition.y
        serializedMainPoi.Z = targetItemRelativePosition.z
    end
    return serializedMainPoi, objects, locations
end

function Location:GetMappedEventObjectId(eventObjectId, playerChainId)
    if DEBUG then
        print("[DEBUG GetMappedEventObjectId] Looking up: " .. tostring(eventObjectId) .. " with chain: " .. tostring(playerChainId))
    end

    local mappedObjects = CURRENT_STORY.eventObjectMap[eventObjectId]
    if not mappedObjects then
        if DEBUG then
            print("[DEBUG GetMappedEventObjectId] No mapping found")
        end
        return nil
    end

    if type(mappedObjects) == "string" then
        if DEBUG then
            print("[DEBUG GetMappedEventObjectId] Spawnable object: " .. mappedObjects)
        end
        return mappedObjects -- Handle "spawnable" case
    end

    if type(mappedObjects) == "table" and #mappedObjects > 0 then
        if DEBUG then
            print("[DEBUG GetMappedEventObjectId] Found " .. #mappedObjects .. " possible mappings:")
            for i, tuple in ipairs(mappedObjects) do
                print("[DEBUG GetMappedEventObjectId]   [" .. i .. "] chainId: " .. tuple.chainId .. ", value: " .. tuple.value)
            end
        end

        -- If player has a chain ID, prefer that chain
        if playerChainId then
            for _, tuple in ipairs(mappedObjects) do
                if tuple.chainId == playerChainId then
                    if DEBUG then
                        print("[DEBUG GetMappedEventObjectId] MATCH! Returning: " .. tuple.value)
                    end
                    return tuple.value
                end
            end
        end

        -- Fallback: return the first available mapping if no chain match or no player chain ID
        if DEBUG then
            local chainIdStr = playerChainId and tostring(playerChainId) or "nil"
            print("[DEBUG GetMappedEventObjectId] No chain match for object " .. eventObjectId .. " with player chain " .. chainIdStr .. ". Using fallback: " .. mappedObjects[1].value)
        end
        return mappedObjects[1].value
    end

    return nil
end

function Location:GetNextRandomValidAction(player)
    local story = GetStory(player)

    local previousChainOfActions = {}
    if #story.History[player:getData('id')] >= 1 then
        local i = #story.History
        local previousAction = story.History[player:getData('id')][#story.History]
        table.insert(previousChainOfActions, previousAction)
        if DEBUG then
            print("Prev action "..previousAction.Name)
        end

        --a1
        --a2 = a1.NextAction
        --...
        --an = an-1.NextAction
        while i-1 > 0 and not previousAction do
            local pprevAction = story.History[player:getData('id')][i-1]
            if previousAction.NextAction == pprevAction then
                previousAction = pprevAction
                table.insert(previousChainOfActions, pprevAction)
                if DEBUG then
                    print("Prev action "..previousAction.Name)
                end
            else
                previousAction = nil
            end
            i = i-1
        end
    end

    local nextValidActions = Where(self.PossibleActions, function(x)
        return (x.NextLocation == self or not x.NextLocation.isBusy) and All(previousChainOfActions, function(a) return a ~= x end)
            and All(x.Prerequisites, function(p)
                local startActionChainIndex = LastIndexOf(self.History[player:getData('id')], p, StoryActionBase.__eq)
                local endActionChainIndex = LastIndexOf(self.History[player:getData('id')], p.ClosingAction, StoryActionBase.__eq)
                if DEBUG then
                    print("Evaluating validity of action "..x.Description)
                    print("Has prerequisite "..p.Description)
                    if p.ClosingAction then
                        print("With closing action "..p.ClosingAction.Description)
                    else
                        print("Doesn't have a closing action")
                    end
                    print("Prerequisite last index: "..startActionChainIndex)
                    if p.ClosingAction then
                        print("Closing action last index "..endActionChainIndex)
                    end
                    if p.ClosingAction and endActionChainIndex > startActionChainIndex or startActionChainIndex ~= -1 then
                        print("Marked as valid")
                    else
                        print("Not valid")
                    end
                end
                return p.ClosingAction and endActionChainIndex > startActionChainIndex or startActionChainIndex ~= -1
            end)
    end)

    if #nextValidActions > 1 then
        table.remove(nextValidActions, 1)
    end

    return PickRandom(nextValidActions);
end

--- Instantiates specific actions that require dynamic object or actor references
--- @param event table The event from the graph
--- @param player userdata The ped performing the action
--- @param location table The location where the action occurs
--- @param target table|userdata|nil The target object or actor
--- @return table|nil The instantiated action or nil
function InstantiateAction(event, player, location, target)
    if event.Action == 'Drink' then
        return Drink { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'Eat' then
        return Eat { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'LookAt' or event.Action == 'LookAtObject' then
        -- LookAt accepts any target (ped, object, or coordinates)
        -- Uses element:getType() internally to determine target type
        return LookAt { performer = player, nextLocation = location, Target = target, TargetItem = target }
    elseif event.Action == 'Wave' then
        -- Wave accepts any target (ped, object, or nil for general wave)
        -- Uses element:getType() internally to determine target type
        return Wave { performer = player, nextLocation = location, Target = target, TargetItem = target }
    elseif event.Action == 'TakeOut' then
        return TakeOut { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'Stash' then
        return Stash { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'AnswerPhone' then
        return AnswerPhone { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'TalkPhone' then
        return TalkPhone { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'HangUp' then
        return HangUp { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'SmokeIn' then
        return SmokeIn { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'Smoke' then
        return Smoke { performer = player, nextLocation = location, TargetItem = target }
    elseif event.Action == 'SmokeOut' then
        return SmokeOut { performer = player, nextLocation = location, TargetItem = target }
    end
    return nil
end

--- Filter location candidates by spatial constraints
--- Validates each candidate's object position against materialized objects
---
--- @param candidates table Array of POI candidates to filter
--- @param event table The event being processed
--- @param materializedObjects table Map of materialized objects with positions
--- @return table Filtered array of candidates that satisfy spatial constraints
function Location:FilterCandidatesBySpatialConstraints(candidates, event, materializedObjects)
    -- Only apply spatial filtering for non-interaction events with objects
    if #event.Entities < 2 or event.isInteraction then
        return candidates
    end

    local eventObjectId = event.Entities[2]
    local spatialConstraints = CURRENT_STORY.SpatialCoordinator:GetSpatialConstraints(eventObjectId)

    -- No constraints means all candidates are valid
    if not spatialConstraints or #spatialConstraints == 0 then
        return candidates
    end

    if DEBUG then
        print("[Location] Filtering " .. #candidates .. " candidates by spatial constraints for object " .. eventObjectId)
    end

    local filteredCandidates = Where(candidates, function(candidatePoi)
        -- Get the object ID for this candidate
        local candidateObjectId = self:GetMappedEventObjectId(eventObjectId, candidatePoi:getData("mappedChainId_"..event.id))

        if candidateObjectId == 'spawnable' then
            -- Spawnable objects don't have fixed positions, skip spatial validation
            return true
        end

        -- Find the object in the episode
        local candidateObject = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o)
            return o.ObjectId == candidateObjectId
        end)

        if not candidateObject or not candidateObject.position then
            if DEBUG then
                print("[Location] No object found for " .. eventObjectId .. " at POI " .. candidatePoi.Description)
            end
            return false
        end

        -- Validate spatial constraints
        local isValid, reason = CURRENT_STORY.SpatialCoordinator:ValidateAllConstraints(
            eventObjectId,
            candidateObject.position,
            candidateObject.rotation,
            materializedObjects
        )

        if not isValid and DEBUG then
            print("[Location] POI " .. candidatePoi.Description .. " rejected: " .. reason)
        end

        return isValid
    end)

    if DEBUG then
        print("[Location] After spatial filtering: " .. #filteredCandidates .. " / " .. #candidates .. " candidates remain")
    end

    return filteredCandidates
end

--- Find POI closest to a position
--- @param position Vector3 Target position
--- @param pois table Array of POIs
--- @return table|nil Closest POI or nil if no POIs provided
function Location:FindClosestPOI(position, pois)
    if #pois == 0 then
        print('[ERROR] FindClosestPOI: No POIs provided')
        return nil
    end

    local closest = pois[1]
    local minDist = math.abs((pois[1].position - position).length)

    for i = 2, #pois do
        local dist = math.abs((pois[i].position - position).length)
        if dist < minDist then
            minDist = dist
            closest = pois[i]
        end
    end

    return closest
end

--- Find POI that has actions with the specified object
--- Returns POI closest to object's current position
--- @param objectEntityId string Graph entity ID
--- @param player userdata Actor performing action (for chain ID)
--- @param fallbackLocation table Fallback POI if not found
--- @return table The resolved POI or fallback
function Location:FindPOIForObject(objectEntityId, player, fallbackLocation)
    local playerChainId = player:getData('mappedChainId')
    local objectId = self:GetMappedEventObjectId(objectEntityId, playerChainId)

    if not objectId or objectId == 'spawnable' then
        if DEBUG then
            print('[FindPOIForObject] Object '..objectEntityId..' is spawnable, using fallback')
        end
        return fallbackLocation
    end

    -- Find object instance in episode
    local objectInstance = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects,
        function(o) return o.ObjectId == objectId end)

    if not objectInstance then
        print('[ERROR] Object '..objectId..' not found in episode')
        return fallbackLocation
    end

    if not objectInstance.position then
        print('[WARN] Object '..objectId..' has no position')
        return fallbackLocation
    end

    -- Find POIs with actions for this object
    local candidates = Where(CURRENT_STORY.CurrentEpisode.POI, function(poi)
        return Any(poi.allActions, function(action)
            return action.TargetItem and
                   action.TargetItem.ObjectId and
                   action.TargetItem.ObjectId == objectId
        end)
    end)

    if #candidates == 0 then
        -- No POI with object actions - use nearest POI to object
        if DEBUG then
            print('[FindPOIForObject] No POI with actions for object '..objectId..', using nearest POI')
        end
        return self:FindClosestPOI(objectInstance.position, CURRENT_STORY.CurrentEpisode.POI)
    end

    -- Return POI closest to object's current position
    local closestPOI = candidates[1]
    local minDist = math.abs((candidates[1].position - objectInstance.position).length)

    for i = 2, #candidates do
        local dist = math.abs((candidates[i].position - objectInstance.position).length)
        if dist < minDist then
            minDist = dist
            closestPOI = candidates[i]
        end
    end

    if DEBUG then
        print('[FindPOIForObject] Resolved object '..objectEntityId..' to POI '..closestPOI.Description..' (distance='..minDist..')')
    end

    return closestPOI
end

--- Creates a location clone for interaction actors with specified offset
--- @param originalLocation Location The original location to clone
--- @param offset Vector3|nil The offset to apply (default: Vector3(-0.7, -0.7, 0))
--- @return Location The cloned location
function Location:CreateInteractionClone(originalLocation, offset)
    offset = offset or Vector3(-0.7, -0.7, 0)
    local clone = Location(
        originalLocation.X + offset.x,
        originalLocation.Y + offset.y,
        originalLocation.Z + offset.z,
        originalLocation.Angle,
        originalLocation.Interior,
        originalLocation.Description,
        originalLocation.Region,
        false
    )
    clone.isBusy = false
    clone.LocationId = originalLocation.LocationId
    clone.allActions = originalLocation.allActions
    clone.Episode = originalLocation.Episode
    clone.interactionsOnly = originalLocation.interactionsOnly
    clone.isClone = true  -- Mark as clone to bypass POI queue coordination
    clone.originalLocationId = originalLocation.LocationId  -- Reference for debugging
    return clone
end

-- Helper function to determine if a location needs cloning for interaction
function Location:ShouldCloneForInteraction(targetLocation, nextEvent)
    if not targetLocation.interactionsOnly then
        return false
    end

    if not nextEvent or not nextEvent.isInteraction then
        return false
    end

    local interactionPoiMap = CURRENT_STORY.interactionPoiMap
    if not nextEvent.interactionRelation then
        return false
    end

    -- Check if another actor already claimed this interaction POI
    return interactionPoiMap[nextEvent.interactionRelation] == targetLocation.LocationId
end

--- Creates a Move action between locations
--- Handles special case when multiple actors move to the same interaction POI
--- @param targetLocation Location The target location
--- @param nextEvent table|nil The next event (for interaction handling)
--- @param moveTemplate table The move action template
--- @param interactionOffset Vector3|nil The offset for interaction positioning
--- @param targetEntityId string|nil The target entity ID for entity-based moves
--- @param entityType string|nil The entity type ("actor" or "object")
--- @return Move The created move action
--- Creates a Move action with proper configuration
-- @param targetLocation The target location POI
-- @param nextEvent The next graph event (if any)
-- @param moveTemplate The template Move action from the location
-- @param interactionOffset Optional offset for interaction positioning
-- @param targetEntityId Optional entity ID for entity-based moves
-- @param entityType Optional entity type ('actor' or 'object')
-- @param isArtificial Whether this Move is artificial (for navigation) or a real graph event
-- @return The created Move action
function Location:CreateMoveAction(targetLocation, nextEvent, moveTemplate, interactionOffset, targetEntityId, entityType, isArtificial)
    local interactionPoiMap = CURRENT_STORY.interactionPoiMap
    local finalTarget = targetLocation

    -- Special handling if this is a move towards an interaction POI
    if targetLocation.interactionsOnly and nextEvent and nextEvent.isInteraction and nextEvent.interactionRelation then
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print("[DEBUG CreateMoveAction] BEFORE claim check:")
            print("  - nextEvent.interactionRelation: "..tostring(nextEvent.interactionRelation))
            print("  - targetLocation.LocationId: "..tostring(targetLocation.LocationId))
            print("  - Current claim in map: "..tostring(interactionPoiMap[nextEvent.interactionRelation]))
        end

        if interactionPoiMap[nextEvent.interactionRelation] == targetLocation.LocationId then
            -- Second actor - create clone to avoid collision, using the interaction's specific offset
            finalTarget = self:CreateInteractionClone(targetLocation, interactionOffset)
            print("Creating Move for second actor in interaction - using offset position")
        else
            -- First actor - claim this POI for the interaction
            if DEBUG and DEBUG_POI_ORCHESTRATION then
                print("[DEBUG CreateMoveAction] CLAIMING POI for relation "..nextEvent.interactionRelation.." -> "..targetLocation.LocationId)
            end
            interactionPoiMap[nextEvent.interactionRelation] = targetLocation.LocationId
            if DEBUG and DEBUG_POI_ORCHESTRATION then
                print("[DEBUG CreateMoveAction] AFTER claim, map value: "..tostring(interactionPoiMap[nextEvent.interactionRelation]))
                print("[DEBUG CreateMoveAction] Verifying global map: "..tostring(CURRENT_STORY.interactionPoiMap[nextEvent.interactionRelation]))
            end
            print("Creating Move for first actor in interaction - claiming POI")
        end
    end

    -- Create the move action with the appropriate target
    local move = Move{
        performer = moveTemplate.Performer,
        targetItem = finalTarget,
        nextLocation = finalTarget,
        prerequisites = moveTemplate.Prerequisites,
        graphId = moveTemplate.graphId,
        targetEntityId = targetEntityId,
        targetEntityType = entityType
    }
    move.TargetItem = finalTarget

    -- Mark artificial moves that shouldn't trigger temporal constraints
    if isArtificial then
        move.isArtificial = true
    end

    return move
end

---Plans the next event for an actor using EventPlanner architecture.
---Retrieves the next graph event and enqueues it via ActionsOrchestrator.
---EventPlanner handles all planning logic (location selection, POI allocation, interaction coordination).
---@param player Player The actor to plan for
function Location:PlanNextEventForActor(player)
    local actorId = player:getData('id')

    -- Initialize lastEvents if needed
    if not CURRENT_STORY.lastEvents[actorId] then
        CURRENT_STORY.lastEvents[actorId] = {}
    end

    -- Get current event
    local event = CURRENT_STORY.nextEvents[actorId]

    if not event then
        if DEBUG then
            print("[PlanNextEventForActor] No next event for actor "..actorId)
        end
        return
    end

    if DEBUG then
        print("[PlanNextEventForActor] Actor "..actorId.." planning event "..event.id.." ("..event.Action..")")
    end

    -- Fix 20: If actor already has ANY pending request, just trigger re-check
    -- TODO: This is a tactical fix. The proper solution is to refactor actor event lifecycle
    -- into a per-actor state machine (IDLE → PLANNING → WAITING_AT_SYNC → EXECUTING → COMPLETED)
    -- managed by ActionsOrchestrator, eliminating scattered flags like isAwaitingConstraints,
    -- pendingGraphAction, currentAction, etc.
    local existingRequest = CURRENT_STORY.ActionsOrchestrator and
        CURRENT_STORY.ActionsOrchestrator.eventRequests and
        CURRENT_STORY.ActionsOrchestrator.eventRequests[actorId]

    if DEBUG then
        print(string.format("[DIAG][PlanNextEventForActor] Actor %s - existingRequest exists=%s", actorId, tostring(existingRequest ~= nil)))
        if existingRequest then
            print(string.format("[DIAG][PlanNextEventForActor] existingRequest: eventId=%s, pendingGraphAction=%s, performed=%s, needsReplanning=%s",
                tostring(existingRequest.eventId),
                existingRequest.pendingGraphAction and existingRequest.pendingGraphAction.Name or "nil",
                tostring(existingRequest.performed),
                tostring(existingRequest.needsReplanning)))
        else
            print(string.format("[DIAG][PlanNextEventForActor] Actor %s has NO existing request - will create new for event %s", actorId, event.id))
            -- Dump all current eventRequests for debugging
            if CURRENT_STORY.ActionsOrchestrator and CURRENT_STORY.ActionsOrchestrator.eventRequests then
                print("[DIAG][PlanNextEventForActor] Current eventRequests:")
                for reqActorId, req in pairs(CURRENT_STORY.ActionsOrchestrator.eventRequests) do
                    print(string.format("  %s: eventId=%s, pendingGraphAction=%s",
                        reqActorId, tostring(req.eventId),
                        req.pendingGraphAction and req.pendingGraphAction.Name or "nil"))
                end
            end
        end
    end

    -- FIX Issue 9: Only skip planning if request exists AND is not already performed
    -- After an action completes, request.performed=true but request stays in eventRequests
    -- Without this check, we'd skip planning the next event (e.g., a1_17 StandUp after a1_16 SitDown)
    if existingRequest and not existingRequest.performed then
        CURRENT_STORY.ActionsOrchestrator:ProcessEventRequests()
        return true
    end

    -- Add event to history if not already there
    local lastEvents = CURRENT_STORY.lastEvents[actorId]
    if not event.isStartingEvent and (#lastEvents == 0 or event.id ~= lastEvents[#lastEvents].id) then
        table.insert(lastEvents, event)
    end

    -- Determine next event ID
    local nextEventId
    if event.isStartingEvent then
        nextEventId = event.id
        event.isStartingEvent = false  -- Mark as processed
    else
        nextEventId = CURRENT_STORY:GetNextEvent(event.id, actorId)
    end

    if not nextEventId then
        if DEBUG then
            print("[PlanNextEventForActor] No next event ID for actor "..actorId.." after event "..event.id)
        end
        return
    end

    -- Enqueue event for planning via ActionsOrchestrator
    -- ActionsOrchestrator will validate temporal constraints and call EventPlanner when satisfied
    if CURRENT_STORY.ActionsOrchestrator then
        CURRENT_STORY.ActionsOrchestrator:EnqueueEvent(player, nextEventId)

        if DEBUG then
            print("[PlanNextEventForActor] Enqueued event "..nextEventId.." for actor "..actorId)
        end
    else
        print("[ERROR] [PlanNextEventForActor] ActionsOrchestrator not initialized")
    end

    -- Update nextEvents for next cycle
    local nextEvent = CURRENT_STORY.graph[nextEventId]
    if nextEvent then
        CURRENT_STORY.nextEvents[actorId] = nextEvent
        return true
    end
    -- All events processed. The story must end for this actor.
    return false
end

-- NOTE: Removed broken global lock implementation
-- The while lock do Timer() end pattern was causing infinite loops because:
-- 1. Timer() doesn't block in MTA Lua - it creates an async timer and returns immediately
-- 2. If any error occurred before lock = false, the lock would stay stuck forever
-- 3. Since Lua is single-threaded, no lock is needed for re-entrancy protection

function Location:GetNextValidAction(player)
    if CURRENT_STORY and CURRENT_STORY.Disposed then
        return EmptyAction({Performer = player})
    end

    if DEBUG then
        print("Location:GetNextValidAction")
    end
    if player == nil and DEBUG then
        print("Error Location:GetNextValidAction: Actor is null ")
    end
    local story = GetStory(player)
    if DEBUG and story == nil then
        print("Error Location:GetNextValidAction: story is null")
    end
    if not self.History then
        self.History = {}
    end
    if not self.History[player:getData('id')] then
        self.History[player:getData('id')] = {}
    end
    if not story.History then
        story.History = {}
    end
    if not story.History[player:getData('id')] then
        story.History[player:getData('id')] = {}
    end
    print('Story actions nr '..#(story.History[player:getData('id')]))
    if #(story.History[player:getData('id')]) >= story.MaxActions then
        if DEBUG then
            outputConsole("Location:GetNextValidAction - max story actions reached. Ending the current story")
        end
        table.insert(CURRENT_STORY.lastEvents[player:getData('id')], {id = "$@!end_story!@$"})
        return EndStory(player)
    end

    local next = nil
    local eventPlanned = false
    if not LOAD_FROM_GRAPH then
        print('Get next random valid action')
        next = self:GetNextRandomValidAction(player)
    else
        local q = CURRENT_STORY.actionsQueues[player:getData('id')]
        if not q then -- initialize queue
            q = {}
            CURRENT_STORY.actionsQueues[player:getData('id')] = q
        end

        if DEBUG then
            print('[GetNextValidAction] Actor '..player:getData('id')..' - queue size at entry: '..#q)
        end

        if DEBUG and DEBUG_POI_ORCHESTRATION then
            local currentAction = player:getData('currentAction')
            local isActionExecuting = player:getData('isActionExecuting')
            print('[GetNextValidAction] RACE_DEBUG actorId='..player:getData('id')..
                  ' queueSize='..#q..' currentAction='..tostring(currentAction)..
                  ' isActionExecuting='..tostring(isActionExecuting))
        end

        -- New EventPlanner flow: Plan next event when queue is empty
        if #q == 0 then
            eventPlanned = self:PlanNextEventForActor(player)
            if DEBUG then
                print('[GetNextValidAction] Actor '..player:getData('id')..' - queue size after planning: '..#q..', eventPlanned: '..tostring(eventPlanned))
            end
            -- NOTE: Removed IdleAction return here - it was blocking queue pops when planning added actions
            -- The isAwaitingConstraints mechanism handles kick-off when constraints are satisfied
        end

        if #q > 0 then
            -- Don't pop from queue if an action is currently executing
            -- This prevents race condition where queued actions are lost
            local currentAction = player:getData('currentAction')
            if currentAction then
                if DEBUG and DEBUG_POI_ORCHESTRATION then
                    print('[GetNextValidAction] Actor '..player:getData('id')..
                          ' has currentAction='..tostring(currentAction)..', not popping from queue')
                end
                return nil
            end

            -- Check if actor is waiting for POI acquisition
            if player:getData('pendingPOIAction') then
                if DEBUG then
                    print('[GetNextValidAction] Actor '..player:getData('id')..' waiting for POI, returning nil')
                end
                -- Return nil - ProcessPOIQueue will call TriggerActionExecution when POI is acquired
                return nil
            end

            next = q[1]
            local sssss = '?????'
            if next.Name then
                sssss = next.Name
            end

            -- CONTAMINATION CHECK: Verify action ownership when popping from queue
            print(string.format("[CONTAMINATION_CHECK][GetNextValidAction] actorId=%s action=%s next.eventId=%s queue_size=%d",
                player:getData('id'), sssss, tostring(player:getData('eventId')), #q))

            if DEBUG then
                print('[GetNextValidAction] Actor '..player:getData('id')..' - popping \''..sssss..'\' from queue (queue size before pop: '..#q..')')
            end

            if DEBUG and DEBUG_POI_ORCHESTRATION then
                print('[GetNextValidAction] ABOUT_TO_POP actorId='..player:getData('id')..
                      ' action='..sssss..' traceback:\n'..debug.traceback())
            end

            print('Next action is '..sssss)
            -- Remove action from queue - ActionsOrchestrator handles all POI coordination
            table.remove(q, 1)
            next._isReenqueue = true  -- Mark for front-of-queue insertion if re-enqueued

            -- DEBUG TRACE: Log when furniture actions get _isReenqueue set
            if sssss == 'SitDown' or sssss == 'Sleep' then
                local actorPos = player.position
                print(string.format("[MIDAIR_DEBUG][GetNextValidAction] SETTING_REENQUEUE actorId=%s action=%s",
                    player:getData('id'), sssss))
                print(string.format("[MIDAIR_DEBUG][GetNextValidAction] actorId=%s locationId=%s NextLocation=%s",
                    player:getData('id'), tostring(player:getData('locationId')),
                    tostring(next.NextLocation and next.NextLocation.LocationId or 'nil')))
                if actorPos then
                    print(string.format("[MIDAIR_DEBUG][GetNextValidAction] actorId=%s position=(%.1f, %.1f, %.1f)",
                        player:getData('id'), actorPos.x, actorPos.y, actorPos.z))
                end
            end

            if DEBUG then
                print('[GetNextValidAction] Actor '..player:getData('id')..' - queue size after pop: '..#q)
            end
        end
    end

    if not next then
        local actorId = player:getData('id')

        -- If no next event planned, and there was no action in the queue from previous planning,
        -- check if all events are processed
        if not eventPlanned then
            -- No next event - check if current event is fully performed
            local request = CURRENT_STORY.ActionsOrchestrator and CURRENT_STORY.ActionsOrchestrator.eventRequests[actorId]

            if request and not request.performed then
                -- Current event still executing, wait for it to complete
                if DEBUG then
                    print("[GetNextValidAction] Actor "..actorId.." current event "..tostring(request.eventId).." still executing")
                end
                return nil
            end

            -- No next event and current event done - end story
            if DEBUG then
                outputConsole("Location:GetNextValidAction - no next event for "..actorId..". Ending story")
                print("[GetNextValidAction] No next event for "..actorId..". Ending story")
            end
            table.insert(CURRENT_STORY.lastEvents[actorId], {id = "$@!end_story!@$"})
            return EndStory(player)
        end

        -- Has next event but waiting for constraints - return nil
        -- EnqueueActionLinear will kick off execution when constraints are satisfied
        if DEBUG then
            print("[GetNextValidAction] Actor "..actorId.." waiting for constraints, returning nil")
        end
        return nil
    else
        if DEBUG then
            outputConsole("Next action chosen: "..next.Description)
            print("Next action chosen: "..next.Description .." "..next.Name)
            if not next.NextLocation then
                print("Error: Next action had a null next location!")
            else
                print("Next action for actor "..player:getData('id').." chosen. Action: "..next.Description.." target location: "..next.NextLocation.Description.." in region: "..next.NextLocation.Region.name.." and episode: "..next.NextLocation.Region.Episode.name)
            end
        end
        if next.NextLocation == self then
            if DEBUG then
                print("Add next action to history "..next.Name.." - "..next.Description)
            end
            table.insert(self.History[player:getData('id')], next)
        else
            self.History[player:getData('id')] = {}
            next.NextLocation.History[player:getData('id')] = {next}
            --the actor will change the location - but don't update locationId yet
            -- locationId will be updated when Move action completes in Move.destinationReached
            -- For now, mark target as busy for planning purposes (will be set properly on arrival)
            next.NextLocation.isBusy = true
            print(player:getData('id').."Location "..next.NextLocation.Description..' will be busy (reserved)')
        end
    end
    next.Performer = player
    return next
end