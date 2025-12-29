--- POICoordinator
--- Responsible for coordinating Point of Interest (POI) selection, reservation, and occupancy tracking.
--- Separates WHERE actions execute from WHAT actions to execute (ActionsPlanner) and WHEN to execute them (ActionsOrchestrator).
---
--- @class POICoordinator

POICoordinator = class(function(o)
    -- Interaction tracking: [primaryPoiId] = {relationId, actors = {{actorId, locationId}, ...}}
    o.activeInteractions = {}
    -- Track completed actors per interaction: [primaryPoiId] = {actorId1, actorId2, ...}
    o.completedInteractionActors = {}
    -- Clone POI tracking: [locationId] = Location object
    -- Clone POIs are dynamically created for second actor in interactions and not in episode.POI
    o.clonePOIs = {}
end)

--- Initialize POICoordinator with EventBus subscriptions.
--- Called after story creation to set up event listeners.
function POICoordinator:Initialize()
    local eventBus = EventBus:getInstance()

    -- Subscribe to graph_event_end to track interaction completion
    eventBus:subscribe("graph_event_end", "poi_coordinator", function(eventData)
        self:OnGraphEventEnd(eventData)
    end)

    if DEBUG and DEBUG_POI_ORCHESTRATION then
        print("[POICoordinator] Subscribed to graph_event_end")
    end
end

--- Handle graph_event_end to track interaction completion.
--- When all actors in an interaction complete, unregister the interaction.
---
--- @param eventData table Event data {eventId, actorId, actionName}
function POICoordinator:OnGraphEventEnd(eventData)
    if not eventData or not eventData.actorId then
        return
    end

    local actorId = eventData.actorId

    -- Check if this actor is in any active interaction
    for primaryPoiId, interaction in pairs(self.activeInteractions) do
        -- Find if this actor is part of this interaction
        local actorInInteraction = false
        for _, actor in ipairs(interaction.actors) do
            if actor.actorId == actorId then
                actorInInteraction = true
                break
            end
        end

        if actorInInteraction then
            -- Mark actor as completed for this interaction
            if not self.completedInteractionActors[primaryPoiId] then
                self.completedInteractionActors[primaryPoiId] = {}
            end

            table.insert(self.completedInteractionActors[primaryPoiId], actorId)

            if DEBUG and DEBUG_POI_ORCHESTRATION then
                print("[POICoordinator] Actor "..actorId.." completed interaction event at "..primaryPoiId)
            end

            -- Check if all actors in interaction have completed
            local allCompleted = true
            for _, actor in ipairs(interaction.actors) do
                local found = false
                for _, completedId in ipairs(self.completedInteractionActors[primaryPoiId]) do
                    if completedId == actor.actorId then
                        found = true
                        break
                    end
                end
                if not found then
                    allCompleted = false
                    break
                end
            end

            if allCompleted then
                -- All actors completed - unregister interaction
                self:UnregisterInteraction(primaryPoiId)
                self.completedInteractionActors[primaryPoiId] = nil

                if DEBUG and DEBUG_POI_ORCHESTRATION then
                    print("[POICoordinator] All actors completed interaction at "..primaryPoiId..", unregistered")
                end
            end

            break  -- Actor can only be in one interaction at a time
        end
    end
end

--- Get all currently occupied or reserved POIs across all actors
--- Checks BOTH locationId (current location) AND reservedLocationId (future reservation)
--- This prevents race conditions where multiple actors try to reserve the same POI
---
--- @return table Map of locationId → actorId for all occupied/reserved POIs
function POICoordinator:GetOccupiedPOIs()
    local occupiedPOIs = {}

    if not CURRENT_STORY.CurrentEpisode or not CURRENT_STORY.CurrentEpisode.peds then
        return occupiedPOIs
    end

    for _, ped in ipairs(CURRENT_STORY.CurrentEpisode.peds) do
        -- Check current location (where actor currently is)
        local currentLocationId = ped:getData('locationId')
        if currentLocationId then
            occupiedPOIs[currentLocationId] = ped:getData('id')
        end

        -- Check reserved location (where actor plans to go)
        local reservedLocationId = ped:getData('reservedLocationId')
        if reservedLocationId then
            occupiedPOIs[reservedLocationId] = ped:getData('id')
        end
    end

    return occupiedPOIs
end

--- Check if an actor needs to move to reach the target POI
--- Compares LocationId values (not table references) using StoryLocationBase.__eq metamethod
---
--- @param actor Player The actor
--- @param targetPOI Location The target POI
--- @return boolean True if actor needs to move
function POICoordinator:NeedsMove(actor, targetPOI)
    if not targetPOI then
        return false
    end

    local currentLocationId = actor:getData('locationId')
    local targetLocationId = targetPOI.LocationId

    -- Compare LocationId values directly
    return currentLocationId ~= targetLocationId
end

--- Reserve a single POI for an actor
--- Checks occupancy before reserving to prevent conflicts
---
--- @param actor Player The actor requesting reservation
--- @param poi Location The POI to reserve
--- @return boolean, string Success status and error message if failed
function POICoordinator:ReservePOI(actor, poi)
    if not poi then
        return false, "POI is nil"
    end

    local locationId = poi.LocationId
    local actorId = actor:getData('id')
    local occupiedPOIs = self:GetOccupiedPOIs()

    -- Check if already occupied/reserved by another actor
    if occupiedPOIs[locationId] and occupiedPOIs[locationId] ~= actorId then
        return false, "POI "..locationId.." already reserved by "..occupiedPOIs[locationId]
    end

    -- Reserve the POI
    actor:setData('reservedLocationId', locationId)

    if DEBUG and DEBUG_POI_ORCHESTRATION then
        print("[POICoordinator] Actor "..actorId.." reserved POI "..locationId)
    end

    return true, nil
end

--- Atomically reserve multiple POIs for a group of actors
--- Used for temporal constraint groups (starts_with, concurrent) to ensure all actors
--- can acquire their POIs before any start executing
---
--- @param actorPoiPairs table Array of {actor, poi} pairs
--- @return boolean, string Success status and error message if failed
function POICoordinator:ReservePOIsForGroup(actorPoiPairs)
    if not actorPoiPairs or #actorPoiPairs == 0 then
        return true, nil  -- Nothing to reserve
    end

    local occupiedPOIs = self:GetOccupiedPOIs()

    -- Pre-check: Verify ALL POIs are available before reserving any
    for _, pair in ipairs(actorPoiPairs) do
        local locationId = pair.poi.LocationId
        local actorId = pair.actor:getData('id')

        if occupiedPOIs[locationId] and occupiedPOIs[locationId] ~= actorId then
            return false, "POI "..locationId.." blocked by "..occupiedPOIs[locationId]
        end
    end

    -- All POIs available - reserve atomically
    for _, pair in ipairs(actorPoiPairs) do
        pair.actor:setData('reservedLocationId', pair.poi.LocationId)

        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print("[POICoordinator] Group reservation: Actor "..pair.actor:getData('id').." reserved POI "..pair.poi.LocationId)
        end
    end

    return true, nil
end

--- Check if a POI is currently occupied by any actor
--- Checks both current location and reserved location
---
--- @param locationId string The POI LocationId to check
--- @return boolean True if POI is occupied
--- @return string|nil ActorId of occupying actor, or nil if not occupied
function POICoordinator:IsPOIOccupied(locationId)
    local occupiedPOIs = self:GetOccupiedPOIs()
    local occupyingActorId = occupiedPOIs[locationId]

    if occupyingActorId then
        return true, occupyingActorId
    end

    return false, nil
end

--- Check if two actors can share the same POI
--- Typically used for interactions where both actors need to be at the same location
---
--- @param actor1 Player First actor
--- @param actor2 Player Second actor
--- @param poi Location The POI in question
--- @param event1 table|nil Graph event for actor1 (optional)
--- @param event2 table|nil Graph event for actor2 (optional)
--- @return boolean True if actors can share the POI
function POICoordinator:CanActorsSharePOI(actor1, actor2, poi, event1, event2)
    -- If both events are interactions with the same relation, they can share
    if event1 and event2 and
       event1.isInteraction and event2.isInteraction and
       event1.interactionRelation and event2.interactionRelation and
       event1.interactionRelation == event2.interactionRelation then
        return true
    end

    -- By default, POIs are exclusive (one actor at a time)
    return false
end

--- Claim a POI for an interaction relation
--- First actor in an interaction claims the POI, second actor retrieves it
---
--- @param relation string The interaction relation identifier
--- @param poi Location The POI being claimed
function POICoordinator:ClaimInteractionPOI(relation, poi)
    if not CURRENT_STORY.interactionPoiMap then
        CURRENT_STORY.interactionPoiMap = {}
    end

    CURRENT_STORY.interactionPoiMap[relation] = poi.LocationId

    if DEBUG then
        print("[POICoordinator] Claimed interaction POI for relation "..relation..": "..poi.Description.." ("..poi.LocationId..")")
    end
end

--- Get the claimed POI for an interaction relation
---
--- @param relation string The interaction relation identifier
--- @return string|nil The claimed POI LocationId, or nil if not claimed
function POICoordinator:GetClaimedInteractionPOI(relation)
    if not CURRENT_STORY.interactionPoiMap then
        return nil
    end

    return CURRENT_STORY.interactionPoiMap[relation]
end

--- Register a clone POI for tracking.
--- Clone POIs are dynamically created for second actor in interactions.
--- They are NOT added to episode.POI but tracked separately here.
---
--- @param clonePoi Location The clone POI object to register
function POICoordinator:RegisterClonePOI(clonePoi)
    if not clonePoi or not clonePoi.LocationId then
        print("[POICoordinator] ERROR: Invalid clone POI provided to RegisterClonePOI")
        return
    end

    self.clonePOIs[clonePoi.LocationId] = clonePoi

    if DEBUG and DEBUG_POI_ORCHESTRATION then
        print("[POICoordinator] Registered clone POI: "..clonePoi.LocationId)
    end
end

--- Get a clone POI by its LocationId.
--- Used by ProcessPOIQueue when clone POI is not found in episode.POI.
---
--- @param locationId string The clone POI LocationId
--- @return Location|nil The clone POI object, or nil if not found
function POICoordinator:GetClonePOI(locationId)
    return self.clonePOIs[locationId]
end

--- Register an interaction with the POICoordinator.
--- Called when the first actor's interaction action is processed by MakePOIsAvailable.
---
--- @param primaryPoiId string The primary POI LocationId for this interaction
--- @param relationId string The interaction relation identifier
--- @param actorId string The actor ID
--- @param locationId string The location ID (primary or clone) where this actor will be
function POICoordinator:RegisterInteraction(primaryPoiId, relationId, actorId, locationId)
    if not self.activeInteractions[primaryPoiId] then
        self.activeInteractions[primaryPoiId] = {
            relationId = relationId,
            actors = {}
        }

        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print("[POICoordinator] Registered new interaction at POI "..primaryPoiId.." (relation: "..relationId..")")
        end
    end

    -- Check if actor already registered in this interaction (prevent duplicates from multiple actions)
    local alreadyRegistered = false
    for _, actor in ipairs(self.activeInteractions[primaryPoiId].actors) do
        if actor.actorId == actorId then
            alreadyRegistered = true
            break
        end
    end

    -- Add actor to interaction only if not already registered
    if not alreadyRegistered then
        table.insert(self.activeInteractions[primaryPoiId].actors, {
            actorId = actorId,
            locationId = locationId
        })

        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print("[POICoordinator] Added actor "..actorId.." to interaction at "..primaryPoiId.." (location: "..locationId..")")
        end
    elseif DEBUG and DEBUG_POI_ORCHESTRATION then
        print("[POICoordinator] Actor "..actorId.." already registered for interaction at "..primaryPoiId..", skipping duplicate")
    end
end

--- Check if an actor is part of an active interaction at a given POI.
---
--- @param poiId string The POI LocationId (can be primary or clone)
--- @param actorId string The actor ID to check
--- @return boolean, string|nil True if actor is part of interaction, and the primary POI ID if found
function POICoordinator:IsActorInInteraction(poiId, actorId)
    -- Fix 21: Helper to check if two POIs are equivalent (same or clone relationship)
    local function areEquivalentPOIs(poi1, poi2)
        if poi1 == poi2 then return true end
        -- Check if poi1 is a clone of poi2
        local clone1 = self.clonePOIs[poi1]
        if clone1 and clone1.originalLocationId == poi2 then return true end
        -- Check if poi2 is a clone of poi1
        local clone2 = self.clonePOIs[poi2]
        if clone2 and clone2.originalLocationId == poi1 then return true end
        return false
    end

    -- Check if poiId is a primary POI with an interaction
    if self.activeInteractions[poiId] then
        local interaction = self.activeInteractions[poiId]
        for _, actor in ipairs(interaction.actors) do
            if actor.actorId == actorId then
                return true, poiId
            end
        end
    end

    -- Check if poiId is a clone in any interaction
    for primaryPoiId, interaction in pairs(self.activeInteractions) do
        for _, actor in ipairs(interaction.actors) do
            -- Fix 21: Use equivalence check instead of exact match
            if areEquivalentPOIs(actor.locationId, poiId) and actor.actorId == actorId then
                return true, primaryPoiId
            end
        end
    end

    return false, nil
end

--- Get all actors participating in an interaction at a primary POI.
---
--- @param primaryPoiId string The primary POI LocationId
--- @return table|nil Array of {actorId, locationId} or nil if no interaction
function POICoordinator:GetInteractionActors(primaryPoiId)
    if not self.activeInteractions[primaryPoiId] then
        return nil
    end

    return self.activeInteractions[primaryPoiId].actors
end

--- Unregister an interaction when all actors complete.
--- Also cleans up any clone POIs associated with this interaction.
---
--- @param primaryPoiId string The primary POI LocationId
function POICoordinator:UnregisterInteraction(primaryPoiId)
    if self.activeInteractions[primaryPoiId] then
        -- Clean up clone POIs associated with this interaction
        local interaction = self.activeInteractions[primaryPoiId]
        for _, actor in ipairs(interaction.actors) do
            -- Clone POIs have LocationIds ending with "_clone"
            if actor.locationId:match("_clone$") then
                self.clonePOIs[actor.locationId] = nil
                if DEBUG and DEBUG_POI_ORCHESTRATION then
                    print("[POICoordinator] Cleaned up clone POI: "..actor.locationId)
                end
            end
        end

        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print("[POICoordinator] Unregistered interaction at POI "..primaryPoiId)
        end
        self.activeInteractions[primaryPoiId] = nil
    end
end

--- Validate POI availability for a group of planned actions and attempt displacement if needed.
--- This method is called by ActionsOrchestrator after planning but before execution.
--- It ensures all actors in a constraint group can acquire their required POIs.
---
--- @param actions table Array of planned actions (each with NextLocation and Performer)
--- @return boolean, string Success status and error message if validation failed
function POICoordinator:MakePOIsAvailable(actions)
    if not actions or #actions == 0 then
        return true, nil  -- No POIs to validate
    end

    if not CURRENT_STORY.ActionsOrchestrator then
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[MakePOIsAvailable] WARNING: ActionsOrchestrator not initialized')
        end
        return true, nil  -- Backward compatibility
    end

    local poiRequirements = {}

    -- Collect POI requirements for all actions
    for _, action in ipairs(actions) do
        if action.NextLocation and action.Performer then
            local actor = action.Performer
            local currentLocationId = actor:getData('locationId')
            local targetLocationId = action.NextLocation.LocationId

            -- Only track POI changes (actor moving to different POI)
            if currentLocationId ~= targetLocationId then
                table.insert(poiRequirements, {
                    actor = actor,
                    action = action,
                    targetLocationId = targetLocationId,
                    targetPOI = action.NextLocation
                })
            end
        end
    end

    -- If no POI changes needed, all actors stay at current POIs
    if #poiRequirements == 0 then
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[MakePOIsAvailable] No POI changes required for group')
        end
        return true, nil
    end

    -- Register interactions from action metadata
    for _, req in ipairs(poiRequirements) do
        if req.action.isInteraction and req.action.relationId and req.action.primaryPoiId then
            local actorId = req.actor:getData('id')
            local primaryPoiId = req.action.primaryPoiId
            local targetLocationId = req.targetLocationId

            -- Register interaction (handles both first and subsequent actors)
            self:RegisterInteraction(primaryPoiId, req.action.relationId, actorId, targetLocationId)
        end
    end

    local occupiedPOIs = self:GetOccupiedPOIs()

    -- Check availability for each required POI
    for _, req in ipairs(poiRequirements) do
        local actorId = req.actor:getData('id')
        local targetLocationId = req.targetLocationId
        local occupyingActorId = occupiedPOIs[targetLocationId]

        if occupyingActorId and occupyingActorId ~= actorId then
            -- POI occupied by another actor
            local occupyingActor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds,
                function(ped) return ped:getData('id') == occupyingActorId end)

            if not occupyingActor then
                -- Shouldn't happen but handle gracefully
                return false, "POI "..targetLocationId.." occupied by unknown actor "..occupyingActorId
            end

            -- Check if this is an interaction conflict
            local isPartOfInteraction, primaryPoiId = self:IsActorInInteraction(targetLocationId, actorId)
            local occupantInInteraction, occupantPrimaryPoi = self:IsActorInInteraction(targetLocationId, occupyingActorId)

            -- If requester is part of the same interaction as occupant, allow (they're sharing)
            if isPartOfInteraction and occupantInInteraction and primaryPoiId == occupantPrimaryPoi then
                if DEBUG and DEBUG_POI_ORCHESTRATION then
                    print('[MakePOIsAvailable] Actors '..actorId..' and '..occupyingActorId..' share interaction at '..primaryPoiId)
                end
                -- Do nothing - actors can share same interaction
            elseif occupantInInteraction then
                -- If occupant is in an interaction, need to displace entire interaction
                if DEBUG and DEBUG_POI_ORCHESTRATION then
                    print('[MakePOIsAvailable] POI '..targetLocationId..' occupied by interaction at '..occupantPrimaryPoi)
                end

                -- Get all actors in the interaction
                local interactionActors = self:GetInteractionActors(occupantPrimaryPoi)
                if interactionActors then
                    -- Try to displace all actors in the interaction atomically
                    local allDisplaced = true
                    for _, interactionActor in ipairs(interactionActors) do
                        local actorToDisplace = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds,
                            function(ped) return ped:getData('id') == interactionActor.actorId end)

                        if actorToDisplace and CURRENT_STORY.ActionsOrchestrator:CanActorBeDisplaced(actorToDisplace) then
                            local displaced = CURRENT_STORY.ActionsOrchestrator:DisplaceActor(actorToDisplace,
                                'POICoordinator making POI available - displacing interaction')

                            if not displaced then
                                allDisplaced = false
                                break
                            end
                        else
                            allDisplaced = false
                            break
                        end
                    end

                    if allDisplaced then
                        -- Unregister the interaction
                        self:UnregisterInteraction(occupantPrimaryPoi)

                        -- Update occupiedPOIs after displacement
                        occupiedPOIs = self:GetOccupiedPOIs()

                        if DEBUG and DEBUG_POI_ORCHESTRATION then
                            print('[MakePOIsAvailable] Displaced entire interaction at '..occupantPrimaryPoi)
                        end
                    else
                        if DEBUG and DEBUG_POI_ORCHESTRATION then
                            print('[MakePOIsAvailable] Failed to displace interaction at '..occupantPrimaryPoi)
                        end
                        return false, "POI "..targetLocationId.." occupied by interaction at "..occupantPrimaryPoi.." that cannot be displaced"
                    end
                end
            else
                -- Not an interaction - try to displace single actor
                if CURRENT_STORY.ActionsOrchestrator:CanActorBeDisplaced(occupyingActor) then
                    local displaced = CURRENT_STORY.ActionsOrchestrator:DisplaceActor(occupyingActor,
                        'POICoordinator making POI available for group')

                    if not displaced then
                        -- Displacement failed
                        if DEBUG and DEBUG_POI_ORCHESTRATION then
                            print('[MakePOIsAvailable] Failed to displace actor '..occupyingActorId..' from POI '..targetLocationId)
                        end
                        return false, "POI "..targetLocationId.." occupied by "..occupyingActorId.." and cannot be displaced"
                    end

                    -- Update occupiedPOIs after displacement
                    occupiedPOIs = self:GetOccupiedPOIs()

                    if DEBUG and DEBUG_POI_ORCHESTRATION then
                        print('[MakePOIsAvailable] Displaced actor '..occupyingActorId..' from POI '..targetLocationId)
                    end
                else
                    -- Cannot displace (e.g., awaiting constraints)
                    if DEBUG and DEBUG_POI_ORCHESTRATION then
                        print('[MakePOIsAvailable] Cannot displace actor '..occupyingActorId..' from POI '..targetLocationId)
                    end
                    return false, "POI "..targetLocationId.." occupied by "..occupyingActorId.." and cannot be displaced"
                end
            end
        end
    end

    -- All POIs available or successfully made available
    if DEBUG and DEBUG_POI_ORCHESTRATION then
        print('[MakePOIsAvailable] All POIs available for group ('..#poiRequirements..' requirements)')
    end

    return true, nil
end
