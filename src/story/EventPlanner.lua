--- EventPlanner: Centralized planning component for graph story execution.
--- Handles per-actor incremental planning with temporal segment awareness
--- for POI collision minimization.
---
--- @module EventPlanner
--- @author Claude Code
--- @see GraphStory
--- @see ActionsOrchestrator
--- @see POICoordinator

--- EventPlanner class
--- Manages event-to-action planning for all actors in a graph story.
--- Plans actions just-in-time when temporal constraints are satisfied.
EventPlanner = class(function(o, story, metaEpisode, poiMap)
    if DEBUG then
        print("[EventPlanner] Initializing EventPlanner")
    end

    --- Reference to the parent GraphStory
    o.story = story

    --- Reference to the MetaEpisode containing all episode data
    o.metaEpisode = metaEpisode

    --- POI mappings from GraphStory validation
    --- Maps event IDs to candidate POIs
    o.poiMap = poiMap or {}

    --- Temporal segment cache (computed lazily)
    --- [segmentId] = { events = {}, happensBefore = {} }
    o.temporalSegments = {}

    --- Segment counter for assigning numeric IDs
    o.segmentCounter = 0

    --- Reverse lookup: event ID to segment ID
    --- [eventId] = segmentId
    o.eventToSegment = {}

    --- Track which segment each actor is currently in
    --- [actorId] = segmentId
    o.actorCurrentSegment = {}

    --- Track current location for each actor
    --- [actorId] = locationId
    o.actorLocations = {}

    --- Track next event for each actor
    --- [actorId] = eventId
    o.actorNextEvents = {}

    --- Interaction POI coordination
    --- [relationId] = { poiId = locationId, firstActor = actorId, clonePoi = Location }
    o.interactionPoiMap = {}

    --- POI usage tracking per segment (for collision minimization)
    --- [segmentId][poiId] = actorId
    o.segmentPOIUsage = {}

    --- Happens-before graph cache (computed lazily)
    o.happensBefore = nil  -- Built lazily

    --- Planned targets for each actor (for displacement coordination)
    --- [actorId] = locationId
    o.plannedTargets = {}

    if DEBUG then
        print("[EventPlanner] EventPlanner initialized successfully")
    end
end)

--- Select POI for an event using full filtering and collision scoring.
--- Shared selection logic used by both InitializeFirstEvents and PlanFixedChainAction.
--- Ensures consistent POI selection across initialization and planning.
---
--- @param event table The event to select POI for
--- @param actor Player The actor performing the event
--- @param segmentId number The temporal segment ID for collision scoring
--- @return Location|nil The selected POI, or nil if none available
function EventPlanner:SelectPOIForEvent(event, actor, segmentId)
    -- 1. Get candidate locations from poiMap
    local candidates = self:GetLocationCandidates(event, actor)

    if DEBUG then
        print(string.format("[SelectPOIForEvent] Event %s: %d initial candidates", event.id or 'unknown', #candidates))
    end

    if #candidates == 0 then
        if DEBUG then
            print("[SelectPOIForEvent] WARNING: No location candidates found for event " .. (event.id or 'unknown'))
        end
        return nil
    end

    -- 2. Filter by spatial constraints
    candidates = self:FilterCandidatesBySpatialConstraints(candidates, event)

    -- 3. Filter by chain conflicts (segment-aware)
    candidates = self:FilterByChainConflicts(candidates, actor, event, segmentId)

    if #candidates == 0 then
        if DEBUG then
            print("[SelectPOIForEvent] WARNING: All candidates filtered out for event " .. (event.id or 'unknown'))
        end
        return nil
    end

    -- 4. Score by POI collision and select best
    local selectedLocation = self:SelectLowestCollisionPOI(candidates, segmentId, actor:getData('id'))

    if DEBUG and selectedLocation then
        print(string.format("[SelectPOIForEvent] Selected POI: %s (LocationId=%s)",
            selectedLocation.Description or "unknown", selectedLocation.LocationId))
    end

    return selectedLocation
end

--- Initialize first events for all actors.
--- Uses PlanNextAction to ensure identical POI selection as runtime.
--- Called during story initialization after episode validation.
---
--- @param graphActors table Array of actor objects
--- @return boolean Success
function EventPlanner:InitializeFirstEvents(graphActors)
    if DEBUG then
        print("[EventPlanner] InitializeFirstEvents --------------------------------------------------")
    end

    local episode = self.metaEpisode

    for _, actor in ipairs(graphActors) do
        local actorId = actor:getData('id')
        print("[EventPlanner] Initializing first event for actor: " .. actorId)

        local firstEventId = self.story.temporal.starting_actions[actorId]
        if not firstEventId then
            print("[EventPlanner] ERROR: No starting action for actor " .. actorId)
            return false
        end

        local firstEvent = self.story.graph[firstEventId]
        if not firstEvent then
            print("[EventPlanner] ERROR: Event " .. firstEventId .. " not found")
            return false
        end

        -- Mark as starting event and set up tracking
        firstEvent.isStartingEvent = true
        self.actorNextEvents[actorId] = firstEvent.id
        self.story.nextEvents[actorId] = firstEvent

        -- Use PlanNextAction to get the planned POI (same logic as runtime)
        -- This internally calls TrackPOIUsage and updates actorLocations
        local plannedActions = self:PlanNextAction(actor, firstEventId)

        -- Extract the target POI from planned actions (last action is main action)
        local mainAction = plannedActions and plannedActions[#plannedActions]
        local plannedPOI = mainAction and mainAction.NextLocation

        -- Check if this POI is already occupied by a previously-initialized actor
        -- Uses the same LocationId tracking as runtime POICoordinator
        if plannedPOI then
            local isOccupied = false
            for _, otherActor in ipairs(episode.peds) do
                local otherId = otherActor:getData('id')
                if otherId ~= actorId then
                    local otherLocationId = otherActor:getData('locationId')
                    if otherLocationId == plannedPOI.LocationId then
                        isOccupied = true
                        if DEBUG then
                            print(string.format("[InitializeFirstEvents] POI %s already occupied by %s, will use fallback for %s",
                                plannedPOI.LocationId, otherId, actorId))
                        end
                        break
                    end
                end
            end

            if isOccupied then
                plannedPOI = nil  -- Force fallback path
            end
        end

        if plannedPOI then
            if DEBUG then
                print("[EventPlanner] Actor " .. actorId .. " spawning at POI: " ..
                      (plannedPOI.Description or "unknown") .. " (" .. plannedPOI.LocationId .. ")")
            end

            -- Set actor spawn position directly at planned POI
            actor:setData('locationId', plannedPOI.LocationId)
            actor:setData('startingPoiIdx', LastIndexOf(episode.POI, plannedPOI))
            actor.interior = plannedPOI.Interior
            actor.position = plannedPOI.position
            actor.rotation = Vector3(0, 0, plannedPOI.Angle)

            -- Update story tracking for backward compatibility
            self.story.nextLocations[actorId] = plannedPOI

            -- Mark POI as busy (actor is physically there)
            plannedPOI.isBusy = true
            print("[EventPlanner] Actor " .. actorId .. ": Location " .. plannedPOI.Description .. " is set to busy")
        else
            -- Fallback: region-based search (matches original fallback)
            local eventLocation = firstEvent.Location and firstEvent.Location[1] or ""
            local fallbackPOI = PickRandom(Where(episode.POI, function(poi)
                return not poi.isBusy and poi.Region and poi.Region.name:lower():find(eventLocation:lower())
            end))

            if fallbackPOI then
                print("[EventPlanner] WARNING: Using fallback POI for actor " .. actorId .. ": " .. fallbackPOI.Description)
                actor:setData('locationId', fallbackPOI.LocationId)
                actor:setData('startingPoiIdx', LastIndexOf(episode.POI, fallbackPOI))
                actor.interior = fallbackPOI.Interior
                actor.position = fallbackPOI.position
                actor.rotation = Vector3(0, 0, fallbackPOI.Angle)
                self.actorLocations[actorId] = fallbackPOI.LocationId
                self.story.nextLocations[actorId] = fallbackPOI
                fallbackPOI.isBusy = true
            else
                print("[EventPlanner] ERROR: No POI found for actor " .. actorId)
                return false
            end
        end
    end

    if DEBUG then
        print("[EventPlanner] InitializeFirstEvents complete --------------------------------------------------")
    end

    return true
end

--- Plan next action for an actor.
--- Called by ActionsOrchestrator when temporal constraints are satisfied.
---
--- @param actor Player The actor to plan for
--- @param eventId string The event ID to plan for
--- @return table Array of planned actions with target POIs
function EventPlanner:PlanNextAction(actor, eventId)
    if DEBUG then
        print("[EventPlanner] PlanNextAction called for actor: " .. (actor:getData('id') or 'unknown') .. ", event: " .. (eventId or 'unknown'))
    end

    -- 1. Get event from graph
    local event = eventId and self.story.graph[eventId]
    if not event then
        if DEBUG then
            print("[EventPlanner] Event " .. (eventId or 'nil') .. " not found for actor: " .. actor:getData('id'))
        end
        return {}
    end

    -- 2. Ensure temporal segment computed and cached
    local segmentId = self:EnsureTemporalSegmentComputed(event)

    -- 3. Route to appropriate flow handler
    local plannedActions = self:RouteToFlowHandler(actor, event, segmentId)

    -- 4. Store which action should trigger publication for this event
    if eventId then
        local expectedAction = self.story.graph[eventId] and self.story.graph[eventId].Action
        local normalizedAction = expectedAction and self.story:NormalizeActionName(expectedAction) or nil

        if normalizedAction then
            actor:setData('currentGraphActionName', normalizedAction)
            actor:setData('currentGraphEventId', eventId)

            if DEBUG then
                print(string.format("[EventPlanner] Set currentGraphActionName='%s' and currentGraphEventId='%s' for actor %s",
                    normalizedAction, eventId, actor:getData('id')))
                -- Verification: Read back the value to confirm it was set
                local verifyEventId = actor:getData('currentGraphEventId')
                print(string.format("[EventPlanner] VERIFY: actor %s now has currentGraphEventId=%s (expected: %s)",
                    actor:getData('id'), tostring(verifyEventId), tostring(eventId)))
            end
        end
    end

    if DEBUG then
        print("[EventPlanner] Planned " .. #plannedActions .. " action(s) for actor: " .. actor:getData('id'))
    end

    return plannedActions
end

--- Get next event for an actor from the graph.
---
--- @param actor Player The actor
--- @return table The next event data
function EventPlanner:GetNextEvent(actor)
    local actorId = actor:getData('id')
    local nextEventId = self.actorNextEvents[actorId]

    if not nextEventId then
        -- Get starting event
        nextEventId = self.story.temporal.starting_actions[actorId]
    end

    if not nextEventId then
        if DEBUG then
            print("[EventPlanner] No next event for actor: " .. actorId)
        end
        return nil
    end

    return self.story.graph[nextEventId]
end

--- Ensure temporal segment is computed and cached for an event.
--- Simply delegates to GetSegmentIdForEvent which handles lazy computation.
---
--- @param event table The event to compute segment for
--- @return number The segment ID
function EventPlanner:EnsureTemporalSegmentComputed(event)
    if DEBUG_VALIDATION then
        print("[EventPlanner] EnsureTemporalSegmentComputed for event: " .. (event.id or 'unknown'))
    end

    -- GetSegmentIdForEvent handles lazy computation and caching
    return self:GetSegmentIdForEvent(event)
end

--- Get segment ID for an event.
--- Computes temporal segments lazily and assigns numeric IDs.
--- If event already belongs to a segment, returns cached ID.
--- Otherwise, computes new segment and assigns next counter ID.
---
--- IMPORTANT: Before computing segment for event X, recursively ensures
--- segments are computed for all events that X depends on (events with
--- happens-before relationship to X). This ensures dependencies get lower
--- segment IDs than their dependents.
---
--- @param event table The event
--- @return number The segment ID (0 on error, nil if cycle detected)
function EventPlanner:GetSegmentIdForEvent(event)
    if not event or not event.id then
        print("[EventPlanner] ERROR: Invalid event passed to GetSegmentIdForEvent")
        return 0
    end

    -- Compute all segments on first call (lazy initialization)
    if not self.allSegmentsComputed then
        self:ComputeAllSegments()
        self.allSegmentsComputed = true
    end

    -- Return precomputed segment ID
    local segmentId = self.eventToSegment[event.id]
    if not segmentId then
        print("[EventPlanner] WARNING: Event " .. event.id .. " not found in any segment")
        return 0
    end

    return segmentId
end


--- Check if a predecessor has been satisfied (either fulfilled or is a starting event).
--- This handles both runtime (when events are fulfilled) and initialization (when starting events act as chain terminators).
---
--- @param eventId string The event ID to check
--- @return boolean True if satisfied and we should stop walking the predecessor chain
function EventPlanner:IsPredecessorSatisfied(eventId)
    -- Check if fulfilled (runtime case)
    if inList(eventId, self.story.ActionsOrchestrator.fulfilled) then
        return true
    end

    -- Check if in previous segment (runtime case)
    if self.eventToSegment[eventId] ~= nil then
        return true
    end

    return false
end

--- Compute ALL temporal segments using dependency-first approach.
--- Computes all segments upfront in a single pass by finding ready events.
--- An event is READY when all its dependencies (predecessors and after-constraints) are satisfied.
---
--- Algorithm:
--- 1. Build happens-before graph (cross-actor constraints)
--- 2. While there are unscheduled events:
---    a. Find all events that are READY (all dependencies satisfied)
---    b. Group ready events by concurrency (no before/after between them)
---    c. Create segments and mark events as satisfied
--- 3. Detects deadlocks if no events are ready but some remain
---
--- @return boolean Success (false if deadlock detected)
function EventPlanner:ComputeAllSegments()
    if DEBUG_VALIDATION then
        print("[EventPlanner] ====== ComputeAllSegments: DEPENDENCY-FIRST ALGORITHM ======")
    end

    -- Step 1: Build happens-before graph from cross-actor constraints
    if not self.happensBefore then
        self.happensBefore = self:BuildHappensBeforeGraph()
        self.happensBefore = self:TransitiveClosure(self.happensBefore)
    end

    -- Step 2: Track satisfied events (events that have been scheduled)
    local satisfiedEvents = {}

    -- Step 3: Compute segments iteratively
    local roundNumber = 0
    local totalEvents = 0

    -- Count total events to schedule
    for eventId, event in pairs(self.story.graph) do
        if event.Action and event.Action ~= "Exists" then
            totalEvents = totalEvents + 1
        end
    end

    while #satisfiedEvents < totalEvents do
        roundNumber = roundNumber + 1

        if DEBUG_VALIDATION then
            print(string.format("[ComputeAllSegments] Round %d: %d/%d events satisfied",
                  roundNumber, #satisfiedEvents, totalEvents))
        end

        -- Find all events that are READY to execute
        local readyEvents = {}
        for eventId, event in pairs(self.story.graph) do
            -- Skip objects and already-satisfied events
            if event.Action and event.Action ~= "Exists" and not self:Contains(satisfiedEvents, eventId) then
                if self:IsEventReady(eventId, event, satisfiedEvents) then
                    table.insert(readyEvents, eventId)
                end
            end
        end

        if #readyEvents == 0 then
            -- Deadlock detected: no events ready but some remain
            print("[ComputeAllSegments] ERROR: Deadlock detected!")
            print(string.format("[ComputeAllSegments] %d events satisfied, %d events remaining",
                  #satisfiedEvents, totalEvents - #satisfiedEvents))

            -- Print unsatisfied events for debugging
            print("[ComputeAllSegments] Unsatisfied events:")
            for eventId, event in pairs(self.story.graph) do
                if event.Action and event.Action ~= "Exists" and not self:Contains(satisfiedEvents, eventId) then
                    print("  - " .. eventId)
                end
            end

            return false
        end

        -- Group ready events by concurrency (no before/after between them)
        local segments = self:GroupByConcurrency(readyEvents)

        -- Create segments and mark events as satisfied
        for _, segmentEvents in ipairs(segments) do
            self.segmentCounter = self.segmentCounter + 1
            local segmentId = self.segmentCounter

            -- Cache the segment
            self.temporalSegments[segmentId] = {
                events = segmentEvents,
                happensBefore = self.happensBefore
            }

            -- Map events to segment
            for _, eventId in ipairs(segmentEvents) do
                self.eventToSegment[eventId] = segmentId
                table.insert(satisfiedEvents, eventId)
            end

            if DEBUG_VALIDATION then
                print(string.format("[ComputeAllSegments] Segment %d: %d events",
                      segmentId, #segmentEvents))
                print("[ComputeAllSegments] Events: " .. table.concat(segmentEvents, ", "))
            end
        end
    end

    -- Safety check: verify all events were placed
    if #satisfiedEvents ~= totalEvents then
        print(string.format("[ComputeAllSegments] ERROR: Event count mismatch! satisfied=%d expected=%d",
              #satisfiedEvents, totalEvents))
        print("[ComputeAllSegments] Missing events:")
        for eventId, event in pairs(self.story.graph) do
            if event.Action and event.Action ~= "Exists" and not self:Contains(satisfiedEvents, eventId) then
                print("  - " .. eventId .. " (" .. (event.Action or "unknown") .. ")")
            end
        end
        return false
    end

    if DEBUG_VALIDATION then
        print(string.format("[ComputeAllSegments] ====== Complete: %d segments, %d events ======",
              self.segmentCounter, #satisfiedEvents))
    end

    return true
end

--- Check if an event is ready to execute (all dependencies satisfied).
--- An event is ready when:
--- 1. Its same-actor predecessor (if any) has been satisfied
--- 2. All cross-actor "after" dependencies have been satisfied
--- 3. Its starts_with partner (if any) is ready to execute (or already satisfied together)
---
--- @param eventId string The event ID to check
--- @param event table The event data
--- @param satisfiedEvents table Array of event IDs that have been satisfied
--- @return boolean True if event is ready to execute
function EventPlanner:IsEventReady(eventId, event, satisfiedEvents)
    -- Check same-actor predecessor
    local actorId = event.Entities and event.Entities[1]
    if actorId then
        local predecessorId = self:GetPredecessorEventId(eventId, actorId)
        if predecessorId and not self:Contains(satisfiedEvents, predecessorId) then
            if DEBUG_VALIDATION then
                print(string.format("[IsEventReady] %s NOT READY: predecessor %s not satisfied",
                      eventId, predecessorId))
            end
            return false  -- Must wait for predecessor
        end
    end

    -- Check cross-actor "after" dependencies
    -- If happensBefore[depEventId] contains eventId, then depEventId must happen before eventId
    for depEventId, targets in pairs(self.happensBefore) do
        if self:Contains(targets, eventId) then
            -- eventId depends on depEventId
            if not self:Contains(satisfiedEvents, depEventId) then
                if DEBUG_VALIDATION then
                    print(string.format("[IsEventReady] %s NOT READY: dependency %s not satisfied",
                          eventId, depEventId))
                end
                return false  -- Must wait for dependency
            end
        end
    end

    -- Check "starts_with" synchronization constraints
    local partnerId = self:GetStartsWithPartner(eventId)
    if partnerId then
        -- Partner already executed? Can't sync anymore (should not happen in well-formed graphs)
        if self:Contains(satisfiedEvents, partnerId) then
            if DEBUG_VALIDATION then
                print(string.format("[IsEventReady] %s NOT READY: starts_with partner %s already satisfied (can't sync)",
                      eventId, partnerId))
            end
            return false  -- Partner already done, can't synchronize
        end

        -- Partner not ready yet? Must wait for it
        -- To avoid infinite recursion, we check the partner's readiness WITHOUT considering its starts_with constraint
        if not self:IsEventReadyIgnoringStartsWith(partnerId, satisfiedEvents) then
            if DEBUG_VALIDATION then
                print(string.format("[IsEventReady] %s NOT READY: starts_with partner %s not ready",
                      eventId, partnerId))
            end
            return false  -- Must wait for partner to be ready
        end
    end

    if DEBUG_VALIDATION then
        print(string.format("[IsEventReady] %s is READY", eventId))
    end

    return true  -- All dependencies satisfied
end

--- Check if an event is ready to execute, ignoring starts_with constraints.
--- Used to check if a starts_with partner is ready without infinite recursion.
---
--- @param eventId string The event ID to check
--- @param satisfiedEvents table Array of event IDs that have been satisfied
--- @return boolean True if event is ready (ignoring starts_with)
function EventPlanner:IsEventReadyIgnoringStartsWith(eventId, satisfiedEvents)
    local event = self.story.graph[eventId]
    if not event then
        return false
    end

    -- Check same-actor predecessor
    local actorId = event.Entities and event.Entities[1]
    if actorId then
        local predecessorId = self:GetPredecessorEventId(eventId, actorId)
        if predecessorId and not self:Contains(satisfiedEvents, predecessorId) then
            return false  -- Must wait for predecessor
        end
    end

    -- Check cross-actor "after" dependencies
    for depEventId, targets in pairs(self.happensBefore) do
        if self:Contains(targets, eventId) then
            if not self:Contains(satisfiedEvents, depEventId) then
                return false  -- Must wait for dependency
            end
        end
    end

    -- Note: We do NOT check starts_with here to avoid infinite recursion
    return true
end

--- Group ready events into concurrent segments.
--- Events can be in the same segment if they have no before/after relationship.
--- Events with starts_with relationships are kept together in the same segment.
---
--- @param readyEvents table Array of event IDs that are ready to execute
--- @return table Array of segments, where each segment is an array of event IDs
function EventPlanner:GroupByConcurrency(readyEvents)
    local segments = {}
    local remainingEvents = {}

    -- Copy readyEvents to remainingEvents
    for _, eventId in ipairs(readyEvents) do
        table.insert(remainingEvents, eventId)
    end

    while #remainingEvents > 0 do
        -- Start new segment with first remaining event
        local segment = {remainingEvents[1]}
        table.remove(remainingEvents, 1)

        -- Check if first event has a starts_with partner in remainingEvents
        local partnerId = self:GetStartsWithPartner(segment[1])
        if partnerId and self:Contains(remainingEvents, partnerId) then
            -- Add partner to segment
            table.insert(segment, partnerId)
            -- Remove partner from remaining
            for i, eventId in ipairs(remainingEvents) do
                if eventId == partnerId then
                    table.remove(remainingEvents, i)
                    break
                end
            end
        end

        -- Try to add more events to this segment
        local changed = true
        while changed do
            changed = false
            local toRemove = {}

            for i, eventId in ipairs(remainingEvents) do
                -- Skip if already in segment (may have been added as a partner earlier)
                if self:Contains(segment, eventId) then
                    table.insert(toRemove, i)
                else
                    local canAdd = true

                    -- Check if this event conflicts with ANY event in segment
                    for _, segmentEventId in ipairs(segment) do
                        if self:HasTemporalConflict(eventId, segmentEventId) then
                            canAdd = false
                            break
                        end
                    end

                    if canAdd then
                        table.insert(segment, eventId)
                        table.insert(toRemove, i)

                        -- If this event has a starts_with partner in remainingEvents, add it too
                        local eventPartnerId = self:GetStartsWithPartner(eventId)
                        if eventPartnerId and self:Contains(remainingEvents, eventPartnerId)
                           and not self:Contains(segment, eventPartnerId) then
                            -- Check if partner also doesn't conflict
                            local partnerCanAdd = true
                            for _, segmentEventId in ipairs(segment) do
                                if self:HasTemporalConflict(eventPartnerId, segmentEventId) then
                                    partnerCanAdd = false
                                    break
                                end
                            end

                            if partnerCanAdd then
                                table.insert(segment, eventPartnerId)
                                -- Mark partner for removal
                                for j, remEventId in ipairs(remainingEvents) do
                                    if remEventId == eventPartnerId then
                                        table.insert(toRemove, j)
                                        break
                                    end
                                end
                            end
                        end

                        changed = true
                    end
                end
            end

            -- Remove events in reverse order to preserve indices
            table.sort(toRemove, function(a, b) return a > b end)
            for _, idx in ipairs(toRemove) do
                table.remove(remainingEvents, idx)
            end
        end

        table.insert(segments, segment)

        if DEBUG_VALIDATION then
            print(string.format("[GroupByConcurrency] Created segment with %d events: %s",
                  #segment, table.concat(segment, ", ")))
        end
    end

    return segments
end

--- Check if two events have a temporal conflict (before/after relationship).
--- Events with starts_with relationships do NOT conflict (they should be together).
---
--- @param eventId1 string First event ID
--- @param eventId2 string Second event ID
--- @return boolean True if events have a temporal conflict
function EventPlanner:HasTemporalConflict(eventId1, eventId2)
    -- Check if they have a synchronized relationship (should be together, not a conflict)
    local partnerId1 = self:GetStartsWithPartner(eventId1)
    local partnerId2 = self:GetStartsWithPartner(eventId2)

    if partnerId1 == eventId2 or partnerId2 == eventId1 then
        return false  -- They are synchronized, should be together!
    end

    -- Check if there's a before/after relationship in happens-before graph
    local targets1 = self.happensBefore[eventId1]
    if targets1 and self:Contains(targets1, eventId2) then
        return true  -- eventId1 must happen before eventId2
    end

    local targets2 = self.happensBefore[eventId2]
    if targets2 and self:Contains(targets2, eventId1) then
        return true  -- eventId2 must happen before eventId1
    end

    return false  -- No conflict
end

--- Build happens-before graph from cross-actor constraints.
--- Includes after/before relations between different actors.
---
--- @return table Happens-before graph: [eventId] = {targetEventIds...}
function EventPlanner:BuildHappensBeforeGraph()
    local happensBefore = {}

    -- Iterate through all temporal relations
    for _, relation in pairs(self.story.temporal) do
        -- Filter out only temporal relations from the pool of events and relations
        if type(relation) == 'table' and relation.type then
            local sourceEvent = relation.source and self.story.graph[relation.source]
            local targetEvent = relation.target and self.story.graph[relation.target]

            -- Check if this is a before/after constraint crossing actors
            if sourceEvent and targetEvent then
                local sourceActor = sourceEvent.Entities and sourceEvent.Entities[1]
                local targetActor = targetEvent.Entities and targetEvent.Entities[1]

                if sourceActor and targetActor and sourceActor ~= targetActor then
                    -- Cross-actor constraint detected
                    if relation.type == 'after' then
                        -- source happens after target, so target happens-before source
                        happensBefore[relation.target] = happensBefore[relation.target] or {}
                        table.insert(happensBefore[relation.target], relation.source)
                    elseif relation.type == 'before' then
                        -- source happens before target, so source happens-before target
                        happensBefore[relation.source] = happensBefore[relation.source] or {}
                        table.insert(happensBefore[relation.source], relation.target)
                    end
                end
            -- Compute indirect before/after relations via 'starts_with' and 'next' relations.
            -- starts_with are only between different actors
            -- e.g.: A starts_with B, A next A2  => B before A2
            elseif relation.type == 'starts_with' or relation.type == 'same_time' then
                local eventsInvolved = Where(self.story.temporal, function(event)
                    return event.relations and self:Contains(event.relations, relation.id) and { id = event.id, event = event }
                end)

                for _, seed in pairs(eventsInvolved) do
                    local allNextIds = {}
                    -- Gather all next events in same-actor chains
                    local currentEvent = seed.event
                    while currentEvent do
                        local nextId = currentEvent.next
                        local nextEvent = nextId and self.story.temporal[nextId] or nil
                        if nextEvent then
                            table.insert(allNextIds, nextId)
                        end
                        currentEvent = nextEvent
                    end

                    for sourceId, _ in pairs(eventsInvolved) do
                        for _, targetId in ipairs(allNextIds) do
                            if sourceId ~= targetId then
                                local sourceEvent = self.story.graph[sourceId]
                                local targetEvent = self.story.graph[targetId]
                                if sourceEvent and targetEvent then
                                    local sourceActor = sourceEvent.Entities and sourceEvent.Entities[1]
                                    local targetActor = targetEvent.Entities and targetEvent.Entities[1]
                                    if sourceActor and targetActor and sourceActor ~= targetActor then
                                        --do something
                                        happensBefore[sourceId] = happensBefore[sourceId] or {}
                                        table.insert(happensBefore[sourceId], targetId)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if DEBUG_VALIDATION then
        print("[EventPlanner] Built happens-before graph with " ..
              self:CountEdges(happensBefore) .. " edges")
    end

    return happensBefore
end

--- Count total edges in happens-before graph (for debugging)
---
--- @param graph table The happens-before graph
--- @return number Total number of edges
function EventPlanner:CountEdges(graph)
    local count = 0
    for _, targets in pairs(graph) do
        count = count + #targets
    end
    return count
end

--- Expand happens-before graph via same-actor event chains.
--- If A → B (same actor) and B happens-before C (cross-actor),
--- then A happens-before C (indirect).
---
--- @param happensBefore table The happens-before graph to expand
--- @return table The expanded happens-before graph
function EventPlanner:ExpandViaSameActorChains(happensBefore)
    local expanded = {}

    -- Copy existing graph
    for eventId, targets in pairs(happensBefore) do
        expanded[eventId] = {}
        for _, target in ipairs(targets) do
            table.insert(expanded[eventId], target)
        end
    end

    -- For each event in the graph
    for eventId, temporalData in pairs(self.story.temporal) do
        if type(temporalData) == 'table' and temporalData.next then
            -- This event has a next event in same-actor chain
            local currentEventId = eventId
            local nextEventId = temporalData.next

            -- Traverse the chain forward
            while nextEventId do
                -- If next event has cross-actor happens-before constraints
                if expanded[nextEventId] then
                    -- Current event also happens-before those targets (indirect)
                    expanded[currentEventId] = expanded[currentEventId] or {}
                    for _, target in ipairs(expanded[nextEventId]) do
                        if not self:Contains(expanded[currentEventId], target) then
                            table.insert(expanded[currentEventId], target)
                        end
                    end
                end

                -- Move to next in chain
                local nextTemporal = self.story.temporal[nextEventId]
                nextEventId = nextTemporal and nextTemporal.next or nil
            end
        end
    end

    if DEBUG_VALIDATION then
        print("[EventPlanner] Expanded via same-actor chains: " ..
              self:CountEdges(happensBefore) .. " → " ..
              self:CountEdges(expanded) .. " edges")
    end

    return expanded
end

--- Check if array contains value
---
--- @param array table The array
--- @param value any The value to find
--- @return boolean True if found
function EventPlanner:Contains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

--- Get predecessor event ID for an actor.
--- Finds the event that has "next" pointing to the given eventId for the same actor.
---
--- @param eventId string The event ID to find predecessor for
--- @param actorId string The actor ID to match
--- @return string|nil The predecessor event ID, or nil if none found
function EventPlanner:GetPredecessorEventId(eventId, actorId)
    for otherEventId, temporal in pairs(self.story.temporal) do
        if type(temporal) == 'table' and temporal.next == eventId then
            local otherEvent = self.story.graph[otherEventId]
            if otherEvent and otherEvent.Entities and otherEvent.Entities[1] == actorId then
                return otherEventId
            end
        end
    end
    return nil
end

--- Get the starts_with partner for an event.
--- Returns the other event that shares a starts_with/same_time relation with this event.
---
--- @param eventId string The event ID to check
--- @return string|nil The partner event ID, or nil if no starts_with relation exists
function EventPlanner:GetStartsWithPartner(eventId)
    local temporal = self.story.temporal[eventId]
    if not temporal or not temporal.relations then
        return nil
    end

    -- Find a starts_with/same_time relation
    for _, relationId in ipairs(temporal.relations) do
        local relation = self.story.temporal[relationId]
        if relation and (relation.type == 'starts_with' or relation.type == 'same_time') then
            -- Find the other event that has this relation
            for otherEventId, otherTemporal in pairs(self.story.temporal) do
                if otherEventId ~= eventId and
                   type(otherTemporal) == 'table' and
                   otherTemporal.relations then
                    for _, otherRelId in ipairs(otherTemporal.relations) do
                        if otherRelId == relationId then
                            return otherEventId
                        end
                    end
                end
            end
        end
    end

    return nil
end

--- Compute transitive closure of happens-before graph using Floyd-Warshall.
--- If A happens-before B and B happens-before C, then A happens-before C.
---
--- @param happensBefore table The happens-before graph
--- @return table The transitive closure
function EventPlanner:TransitiveClosure(happensBefore)
    local closure = {}

    -- Copy existing graph
    for eventId, targets in pairs(happensBefore) do
        closure[eventId] = {}
        for _, target in ipairs(targets) do
            table.insert(closure[eventId], target)
        end
    end

    -- Get all event IDs that participate in happens-before
    local allEvents = {}
    for eventId, _ in pairs(happensBefore) do
        allEvents[eventId] = true
    end
    for _, targets in pairs(happensBefore) do
        for _, target in ipairs(targets) do
            allEvents[target] = true
        end
    end

    -- Floyd-Warshall algorithm
    for k, _ in pairs(allEvents) do
        for i, _ in pairs(allEvents) do
            for j, _ in pairs(allEvents) do
                -- If i happens-before k and k happens-before j
                local iToK = closure[i] and self:Contains(closure[i], k)
                local kToJ = closure[k] and self:Contains(closure[k], j)

                if iToK and kToJ then
                    -- Then i happens-before j (transitive)
                    closure[i] = closure[i] or {}
                    if not self:Contains(closure[i], j) then
                        table.insert(closure[i], j)
                    end
                end
            end
        end
    end

    if DEBUG_VALIDATION then
        print("[EventPlanner] Transitive closure: " ..
              self:CountEdges(happensBefore) .. " → " ..
              self:CountEdges(closure) .. " edges")
    end

    return closure
end

--- Route event to appropriate flow handler.
---
--- @param actor Player The actor
--- @param event table The event to plan
--- @param segmentId number The temporal segment ID
--- @return table Array of planned actions
function EventPlanner:RouteToFlowHandler(actor, event, segmentId)
    if DEBUG then
        print("[EventPlanner] RouteToFlowHandler for event: " .. (event.id or 'unknown') .. ", action: " .. (event.Action or 'unknown'))
    end

    -- Check event type and route to appropriate handler
    -- Order matters: check specific event types before spawnable (which is a fallback for picked objects)
    if self:IsObservationEvent(event) then
        return self:PlanObservationAction(actor, event, segmentId)
    elseif self:IsInteractionEvent(event) then
        return self:PlanInteractionAction(actor, event, segmentId)
    elseif self:IsMoveEvent(event) then
        return self:PlanMoveAction(actor, event, segmentId)
    elseif self:IsSpawnableEvent(event, actor) then
        -- Spawnable check last (except fixed chain) - only for picked objects that moved
        return self:PlanSpawnableAction(actor, event, segmentId)
    else
        return self:PlanFixedChainAction(actor, event, segmentId)
    end
end

--- Check if event involves a spawnable object.
--- Returns true if object is mapped as spawnable OR is in actor's inventory AND actor moved away.
--- Fix 22: Only considers picked objects that match the event's object (by chainId).
---
--- @param event table The event
--- @param actor Player The actor (optional, for inventory check)
--- @return boolean True if spawnable
function EventPlanner:IsSpawnableEvent(event, actor)
    -- Interaction events (Give, Receive) are NOT spawnable - they use PlanInteractionAction
    -- For interaction events, Entities[2] is the TARGET PLAYER, not an object
    if self:IsInteractionEvent(event) then
        return false
    end

    if #event.Entities < 2 then
        return false
    end

    local eventObjectId = event.Entities[2]
    local eventObjectMap = self.story.eventObjectMap

    -- DEBUG: Log what we're checking
    if DEBUG then
        print(string.format("[IsSpawnableEvent] event=%s, eventObjectId=%s", event.id or 'unknown', tostring(eventObjectId)))
        if eventObjectMap and eventObjectMap[eventObjectId] then
            print(string.format("[IsSpawnableEvent] Found %d mappings for object %s", #eventObjectMap[eventObjectId], eventObjectId))
            for i, mapping in ipairs(eventObjectMap[eventObjectId]) do
                print(string.format("[IsSpawnableEvent]   mapping[%d]: value=%s, chainId=%s", i, tostring(mapping.value), tostring(mapping.chainId)))
            end
        else
            print(string.format("[IsSpawnableEvent] NO mappings found for object %s", tostring(eventObjectId)))
        end
    end

    -- Check if mapped as spawnable
    if eventObjectMap and eventObjectMap[eventObjectId] then
        for _, mapping in ipairs(eventObjectMap[eventObjectId]) do
            if mapping.value == 'spawnable' then
                if DEBUG then
                    print(string.format("[IsSpawnableEvent] → TRUE (mapping.value == 'spawnable')"))
                end
                return true
            end
        end
    end

    -- Check if event's object is in actor's inventory AND actor moved away
    -- Fix 22: Only check picked objects that match the event's object (by chainId)
    if actor then
        local pickedObjects = actor:getData('pickedObjects') or {}
        local actorId = actor:getData('id')
        local actorLocationId = self.actorLocations[actorId]  -- Use planning-time location

        -- Fix 22: Build valid chainIds for THIS event's object
        local validChainIds = {}
        if eventObjectMap and eventObjectMap[eventObjectId] then
            for _, mapping in ipairs(eventObjectMap[eventObjectId]) do
                if mapping.chainId then
                    validChainIds[mapping.chainId] = true
                end
            end
        end

        if DEBUG then
            local chainCount = 0
            for _ in pairs(validChainIds) do chainCount = chainCount + 1 end
            print(string.format("[IsSpawnableEvent] Valid chainIds for eventObject %s: %d chains", tostring(eventObjectId), chainCount))
        end

        -- Only check picked objects that match the event's object (by chainId)
        -- pickedObj format: {ObjectId, Description, chainId, locationId}
        for _, pickedObj in ipairs(pickedObjects) do
            local pickedChainId = pickedObj[3]
            local pickedLocationId = pickedObj[4]  -- Origin location stored during pickup

            -- Fix 22: Only consider if chainId matches event's object
            if pickedChainId and validChainIds[pickedChainId] then
                if DEBUG then
                    print(string.format("[IsSpawnableEvent] Found matching picked object: chainId=%s, originLocation=%s",
                        tostring(pickedChainId), tostring(pickedLocationId)))
                end

                -- PutDown always uses fixed chain - must return to original location
                if event.Action == 'PutDown' then
                    if DEBUG then
                        print(string.format("[IsSpawnableEvent] → FALSE (PutDown must return to chain location %s)",
                            tostring(pickedLocationId)))
                    end
                    return false  -- PutDown uses fixed chain flow
                end

                -- For other actions: if actor moved away, use spawnable flow
                if pickedLocationId and actorLocationId ~= pickedLocationId then
                    if DEBUG then
                        print(string.format("[IsSpawnableEvent] → TRUE (actor at %s != pickup location %s)",
                            tostring(actorLocationId), tostring(pickedLocationId)))
                    end
                    return true  -- Actor moved away WITH THIS object → spawnable
                end
                if DEBUG then
                    print(string.format("[IsSpawnableEvent] → FALSE (actor at pickup location %s)", tostring(pickedLocationId)))
                end
                return false  -- Actor at pickup location → fixed chain
            end
        end
    end

    if DEBUG then
        print(string.format("[IsSpawnableEvent] → FALSE (no spawnable mapping, no matching pickedObject for event's object)"))
    end
    return false  -- No matching picked object → use fixed chain
end

--- Check if event is an observation action.
---
--- @param event table The event
--- @return boolean True if observation
function EventPlanner:IsObservationEvent(event)
    if not event or not event.Action then
        return false
    end

    return event.Action == 'LookAt' or
           event.Action == 'LookAtObject' or
           event.Action == 'Wave'
end

--- Check if event is an interaction.
---
--- @param event table The event
--- @return boolean True if interaction
function EventPlanner:IsInteractionEvent(event)
    if not event or not event.Action then
        return false
    end

    return Any(self.story.Interactions, function(a)
        return a:lower() == event.Action:lower()
    end)
end

--- Check if event is a move action.
---
--- @param event table The event
--- @return boolean True if move
function EventPlanner:IsMoveEvent(event)
    if not event or not event.Action then
        return false
    end
    return event.Action:lower() == "move"
end

--- Clean up stale chain ID if current event doesn't support it.
--- Checks if actor's current chain ID is valid for the current event.
--- If the chain is no longer valid (event doesn't have that chain as option), clears it.
--- This allows actors to transition between different objects/locations smoothly.
---
--- @param actor Player The actor to check
--- @param event table The event being planned
function EventPlanner:CleanupStaleChain(actor, event)
    local actorId = actor:getData('id')
    local currentChainId = actor:getData('mappedChainId')

    if DEBUG then
        print(string.format("[CleanupStaleChain] ENTRY: actor=%s, event=%s, currentChainId=%s",
            actorId or "unknown", event.id or "unknown", tostring(currentChainId)))
    end

    if not currentChainId then
        if DEBUG then
            print("[CleanupStaleChain] No chain to clean up (actor has no chainId)")
        end
        return  -- No chain to clean up
    end

    local eventChains = self.poiMap[event.id]
    if not eventChains or #eventChains == 0 then
        if DEBUG then
            print(string.format("[CleanupStaleChain] Event %s has no chain requirements (poiMap empty)", event.id))
        end
        return  -- Event has no chain requirements
    end

    if DEBUG then
        print(string.format("[CleanupStaleChain] Event %s has %d chain entries in poiMap", event.id, #eventChains))
        -- Show first few chains for debugging
        local chainSample = {}
        for i = 1, math.min(5, #eventChains) do
            table.insert(chainSample, eventChains[i].chainId)
        end
        print(string.format("[CleanupStaleChain] Sample chains for event: [%s]%s",
            table.concat(chainSample, ", "), #eventChains > 5 and "..." or ""))
    end

    -- Check if current chain is valid for this event
    local chainStillValid = Any(eventChains, function(mapping)
        return mapping.chainId == currentChainId
    end)

    if DEBUG then
        print(string.format("[CleanupStaleChain] Chain validation: currentChainId=%s, stillValid=%s",
            currentChainId, tostring(chainStillValid)))
    end

    if not chainStillValid then
        -- Current chain not valid for this event - clear it
        actor:setData('mappedChainId', nil)
        if DEBUG then
            print("[CleanupStaleChain] Cleared stale chain " .. currentChainId .. " for actor " .. actorId .. " event " .. event.id)
        end
    elseif DEBUG then
        print("[CleanupStaleChain] Chain still valid, keeping it")
    end
end

--
-- FLOW HANDLERS
--

--- Plan action for fixed location chain.
--- Flow 1: Events with fixed objects/locations.
---
--- @param actor Player The actor
--- @param event table The event
--- @param segmentId number The temporal segment ID
--- @return table Array of planned actions
function EventPlanner:PlanFixedChainAction(actor, event, segmentId)
    if DEBUG then
        print("[EventPlanner] PlanFixedChainAction for event: " .. (event.id or 'unknown'))
    end

    local actorId = actor:getData('id')
    local actions = {}

    -- Clean up stale chain before planning
    self:CleanupStaleChain(actor, event)

    -- 1. Get candidate locations from poiMap
    local candidates = self:GetLocationCandidates(event, actor)

    if DEBUG then
        print(string.format("[PlanFixedChainAction] After GetLocationCandidates: %d candidates", #candidates))
    end

    if #candidates == 0 then
        print("[EventPlanner] WARNING: No location candidates found for event " .. event.id)
        -- Use current location as fallback
        local currentLocationId = self.actorLocations[actorId]
        if currentLocationId then
            local currentLocation = self:FindLocationById(currentLocationId)
            if currentLocation then
                candidates = {currentLocation}
                if DEBUG then
                    print(string.format("[PlanFixedChainAction] Using fallback current location: %s", currentLocationId))
                end
            end
        end
    end

    -- 2. Filter by spatial constraints
    local beforeSpatial = #candidates
    candidates = self:FilterCandidatesBySpatialConstraints(candidates, event)
    if DEBUG and #candidates ~= beforeSpatial then
        print(string.format("[PlanFixedChainAction] After FilterCandidatesBySpatialConstraints: %d candidates (filtered out %d)",
            #candidates, beforeSpatial - #candidates))
    end

    -- 3. Filter by chain conflicts (segment-aware)
    local beforeChainConflict = #candidates
    candidates = self:FilterByChainConflicts(candidates, actor, event, segmentId)
    if DEBUG and #candidates ~= beforeChainConflict then
        print(string.format("[PlanFixedChainAction] After FilterByChainConflicts: %d candidates (filtered out %d)",
            #candidates, beforeChainConflict - #candidates))
    end

    -- 4. Score by POI collision and select best
    local selectedLocation = self:SelectLowestCollisionPOI(candidates, segmentId, actorId)

    if not selectedLocation then
        print("[EventPlanner] ERROR: Could not select location for event " .. event.id)
        return {}
    end

    if DEBUG then
        print(string.format("[PlanFixedChainAction] Selected POI: %s (LocationId=%s)",
            selectedLocation.Description or "unknown", selectedLocation.LocationId))
    end

    -- Store planned target for displacement coordination
    -- If actor is displaced, DisplaceActor can use this to move to planned target
    self.plannedTargets[actorId] = selectedLocation.LocationId

    -- 5. Get action from location (reuse existing, just set performer)
    local action = self:GetActionFromLocation(selectedLocation, event, actor)

    if not action then
        print("[EventPlanner] ERROR: Could not find action for event " .. event.id)
        return {}
    end

    -- 6. Insert artificial move if location changed
    if self:NeedsMove(actor, selectedLocation) then
        local moveAction = self:CreateArtificialMove(actor, selectedLocation, event)
        if moveAction then
            table.insert(actions, moveAction)
        end
    end

    -- 7. Add main action
    table.insert(actions, action)

    -- 8. Track POI usage and update actor state
    self:TrackPOIUsage(segmentId, selectedLocation.LocationId, actorId)
    self.actorLocations[actorId] = selectedLocation.LocationId

    -- Assign chain ID if available
    local oldChainId = actor:getData('mappedChainId')
    local newChainId = selectedLocation:getData("mappedChainId_" .. event.id)
    if newChainId and newChainId ~= oldChainId then
        actor:setData('mappedChainId', newChainId)
        if DEBUG then
            print(string.format("[PlanFixedChainAction] Chain ID changed for actor %s: old=%s, new=%s",
                actorId, tostring(oldChainId), tostring(newChainId)))
        end
    elseif DEBUG then
        print(string.format("[PlanFixedChainAction] Chain ID unchanged for actor %s: %s",
            actorId, tostring(oldChainId)))
    end

    -- Track object materialization for spatial constraint enforcement
    if #event.Entities > 1 and not self:IsInteractionEvent(event) then
        local eventObjectId = event.Entities[2]
        local chainId = selectedLocation:getData("mappedChainId_" .. event.id)
        local objectId = selectedLocation:GetMappedEventObjectId(eventObjectId, chainId)

        if objectId and objectId ~= 'spawnable' then
            local objectInstance = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o)
                return o.ObjectId == objectId
            end)

            if objectInstance and objectInstance.position then
                CURRENT_STORY.SpatialCoordinator:MaterializeObject(
                    eventObjectId,
                    objectInstance.position,
                    objectInstance.rotation or {x=0, y=0, z=0},
                    chainId or "unknown",
                    actorId,
                    objectInstance.element,
                    objectId  -- Physical object ID (e.g., "15_classroom1")
                )
                if DEBUG then
                    print(string.format("[PlanFixedChainAction] Materialized object %s (physical=%s) at chain %s for actor %s",
                        eventObjectId, objectId, tostring(chainId), actorId))
                end
            end
        end
    end

    if DEBUG then
        print("[EventPlanner] Planned " .. #actions .. " action(s) for fixed chain event")
    end

    return actions
end

--- Plan action for spawnable object.
--- Flow 2: Events with spawnable objects.
--- Now properly resolves event.Location and inserts moves like PlanFixedChainAction.
---
--- @param actor Player The actor
--- @param event table The event
--- @param segmentId number The temporal segment ID
--- @return table Array of planned actions
function EventPlanner:PlanSpawnableAction(actor, event, segmentId)
    if DEBUG then
        print("[EventPlanner] PlanSpawnableAction for event: " .. (event.id or 'unknown'))
    end

    local actorId = actor:getData('id')
    local actions = {}

    -- 1. Find target location from event.Location (like PlanFixedChainAction does)
    local targetRegion = event.Location and event.Location[1] or ""
    local targetLocation = nil
    -- Use actor's actual locationId (updated by DisplaceActor) instead of potentially stale cache
    local currentLocationId = actor:getData('locationId') or self.actorLocations[actorId]
    local currentLocation = currentLocationId and self:FindLocationById(currentLocationId)
    -- local isCurrentInteractionOnly = currentLocation and currentLocation.interactionsOnly == true
    -- local hasCurrentEpisodeLinks = currentLocation and currentLocation.episodeLinks and #currentLocation.episodeLinks > 0

    if targetRegion ~= "" then
        -- Check if actor's current location already matches target region (prefer staying)
        if currentLocation and currentLocation.Region and
           currentLocation.Region.name:lower():find(targetRegion:lower()) then
        --    and not isCurrentInteractionOnly and not hasCurrentEpisodeLinks then
            -- Actor is already in the target region - stay there, no need to move
            targetLocation = currentLocation
            if DEBUG then
                print(string.format("[PlanSpawnableAction] Actor already in target region '%s', staying at %s",
                    targetRegion, currentLocation.Description or currentLocationId))
            end
        else
            -- Find all POI candidates matching the event's location region
            -- Exclude interaction-only POIs and episode link POIs (context transitions)
            local candidates = Where(self.metaEpisode.POI, function(poi)
                local regionMatch = poi.Region and poi.Region.name:lower():find(targetRegion:lower())
                -- local isInteractionOnly = poi.interactionsOnly == true
                -- local hasEpisodeLinks = poi.episodeLinks and #poi.episodeLinks > 0
                return regionMatch-- and not isInteractionOnly and not hasEpisodeLinks
            end)

            if #candidates > 0 then
                -- Use collision scoring to select best POI (minimal overlap with other actors)
                targetLocation = self:SelectLowestCollisionPOI(candidates, segmentId, actorId)

                if DEBUG then
                    print(string.format("[PlanSpawnableAction] Found %d candidates for region '%s', selected %s",
                        #candidates, targetRegion, targetLocation and targetLocation.Description or "none"))
                end
            end
        end
    end

    -- Fallback to current location if no event location specified or no candidates found
    if not targetLocation then
        targetLocation = currentLocation
    end

    if not targetLocation then
        print("[EventPlanner] ERROR: No location found for spawnable event " .. event.id ..
              " (targetRegion='" .. targetRegion .. "', currentLocation=" .. tostring(currentLocationId) .. ")")
        return {}
    end

    if DEBUG then
        print(string.format("[PlanSpawnableAction] Target location: %s (LocationId=%s)",
            targetLocation.Description or "unknown", targetLocation.LocationId))
    end

    -- 2. Insert move if needed (same as PlanFixedChainAction)
    if self:NeedsMove(actor, targetLocation) then
        local moveAction = self:CreateArtificialMove(actor, targetLocation, event)
        if moveAction then
            table.insert(actions, moveAction)
        end
    end

    -- 3. Create or get spawnable object instance
    local spawnableObject = self:GetOrCreateSpawnableObject(event, actor)

    -- Fallback: Check pickedObjects if not in PedHandler inventory
    if not spawnableObject and #event.Entities >= 2 then
        local eventObjectId = event.Entities[2]
        local pickedObjects = actor:getData('pickedObjects') or {}
        local eventObjectMap = self.story.eventObjectMap

        -- Get valid chainIds for this event's object
        local validChainIds = {}
        if eventObjectMap and eventObjectMap[eventObjectId] then
            for _, mapping in ipairs(eventObjectMap[eventObjectId]) do
                if mapping.chainId then
                    validChainIds[mapping.chainId] = true
                end
            end
        end

        -- Find matching picked object by chainId
        for _, pickedObj in ipairs(pickedObjects) do
            local pickedChainId = pickedObj[3]
            if pickedChainId and validChainIds[pickedChainId] then
                -- Found it! Look up the actual object instance
                local objectId = pickedObj[1]
                spawnableObject = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(obj)
                    return obj.ObjectId == objectId
                end)
                if DEBUG then
                    print("[EventPlanner] Found picked object for spawnable action: " .. objectId)
                end
                break
            end
        end
    end

    -- 4. Dynamically instantiate action at target location
    local action = InstantiateAction(event, actor, targetLocation, spawnableObject)

    if not action then
        print("[EventPlanner] ERROR: Could not instantiate spawnable action for event " .. event.id)
        return {}
    end

    table.insert(actions, action)

    -- 5. Track POI usage and update actor state (same as PlanFixedChainAction)
    self:TrackPOIUsage(segmentId, targetLocation.LocationId, actorId)
    self.actorLocations[actorId] = targetLocation.LocationId

    if not targetLocation.isBusy then
        targetLocation.isBusy = true
    end

    if DEBUG then
        print("[EventPlanner] Planned " .. #actions .. " action(s) for spawnable event at " .. targetLocation.Description)
    end

    return actions
end

--- Plan observation action (LookAt, LookAtObject, Wave).
--- Actor stays at current location and observes target from distance.
---
--- @param actor Player The actor
--- @param event table The event
--- @param segmentId number The temporal segment ID
--- @return table Array of planned actions
function EventPlanner:PlanObservationAction(actor, event, segmentId)
    if DEBUG then
        print("[EventPlanner] PlanObservationAction for event: " .. (event.id or 'unknown'))
    end

    local actorId = actor:getData('id')
    local currentLocationId = self.actorLocations[actorId]

    -- 1. Stay at current location (actor doesn't move to observe)
    local currentLocation = self:FindLocationById(currentLocationId)

    if not currentLocation then
        print("[EventPlanner] ERROR: No current location for actor " .. actorId)
        return {}
    end

    -- 2. Find observation target (object or actor)
    local target = self:GetObservationTarget(event, actor)

    if not target then
        print("[EventPlanner] ERROR: Could not find observation target for event " .. event.id)
        return {}
    end

    -- 3. Dynamically instantiate action from scratch
    local action = InstantiateAction(event, actor, currentLocation, target)

    if not action then
        print("[EventPlanner] ERROR: Could not instantiate observation action for event " .. event.id)
        return {}
    end

    if DEBUG then
        print("[EventPlanner] Planned observation action at current location: " .. currentLocation.Description)
    end

    return {action}
end

--- Plan action for interaction.
--- Flow 3: Interaction events (requires coordination between actors).
---
--- @param actor Player The actor
--- @param event table The event
--- @param segmentId number The temporal segment ID
--- @return table Array of planned actions
function EventPlanner:PlanInteractionAction(actor, event, segmentId)
    if DEBUG then
        print("[EventPlanner] PlanInteractionAction for event: " .. (event.id or 'unknown'))
    end

    -- Get interaction relation
    local relationId = FirstOrDefault(self.story.temporal[event.id].relations, function(rel)
        return self.story.temporal[rel].type == 'starts_with' or
               self.story.temporal[rel].type == 'same_time'
    end)

    if not relationId then
        print("[EventPlanner] ERROR: No interaction relation found for event " .. event.id)
        return {}
    end

    -- Check if first or second actor
    -- Use stored firstActor to preserve role across re-planning (init vs runtime)
    local actorId = actor:getData('id')
    local mapEntry = self.interactionPoiMap[relationId]

    if not mapEntry or mapEntry.firstActor == actorId then
        return self:PlanFirstActorInteraction(actor, event, relationId, segmentId)
    else
        return self:PlanSecondActorInteraction(actor, event, relationId, segmentId)
    end
end

--- Plan interaction for first actor (claims POI)
function EventPlanner:PlanFirstActorInteraction(actor, event, relationId, segmentId)
    local actions = {}

    -- 1. Select interaction POI (minimize collisions)
    local candidates = self:GetInteractionCandidates(event, actor)
    local interactionPoi = self:SelectLowestCollisionPOI(candidates, segmentId, actor:getData('id'))

    if not interactionPoi then
        print("[EventPlanner] ERROR: Could not find interaction POI for event " .. event.id)
        return {}
    end

    -- 2. Claim POI for this interaction
    self.interactionPoiMap[relationId] = {
        poiId = interactionPoi.LocationId,
        firstActor = actor:getData('id')
    }

    if DEBUG then
        print("[EventPlanner] First actor claims interaction POI: " .. interactionPoi.LocationId)
    end

    -- 3. Create action chain: Move (if needed) + Wait + Interaction
    if self:NeedsMove(actor, interactionPoi) then
        local moveAction = self:CreateArtificialMove(actor, interactionPoi, event)
        if moveAction then
            -- Mark as interaction action for POICoordinator
            moveAction.relationId = relationId
            moveAction.isInteraction = true
            moveAction.primaryPoiId = interactionPoi.LocationId
            table.insert(actions, moveAction)
        else
            print("[EventPlanner] ERROR: Could not create artificial move action for first actor in interaction for event " .. event.id)
        end
    end

    -- Create Wait action for synchronization
    local otherActor = self:GetOtherActorInInteraction(event, actor)
    local waitAction = Wait {
        performer = actor,
        nextLocation = interactionPoi,
        targetItem = otherActor,
        targetInteraction = relationId,
        doNothing = false,
        time = 10000000
    }
    -- Mark as interaction action for POICoordinator
    waitAction.relationId = relationId
    waitAction.isInteraction = true
    waitAction.primaryPoiId = interactionPoi.LocationId
    table.insert(actions, waitAction)

    -- Create actual interaction action
    local interactionAction = self:CreateInteractionAction(event, actor, interactionPoi, otherActor)
    if interactionAction then
        -- Mark as interaction action for POICoordinator
        interactionAction.relationId = relationId
        interactionAction.isInteraction = true
        interactionAction.primaryPoiId = interactionPoi.LocationId
        table.insert(actions, interactionAction)
    end

    -- Update actor state
    self.actorLocations[actor:getData('id')] = interactionPoi.LocationId
    self:TrackPOIUsage(segmentId, interactionPoi.LocationId, actor:getData('id'))

    return actions
end

--- Plan interaction for second actor (uses claimed POI)
function EventPlanner:PlanSecondActorInteraction(actor, event, relationId, segmentId)
    local actions = {}

    -- 1. Get claimed POI
    local claimedData = self.interactionPoiMap[relationId]
    if not claimedData then
        print("[EventPlanner] ERROR: No claimed POI for interaction " .. relationId)
        return {}
    end

    local claimedPoi = FirstOrDefault(self.metaEpisode.POI, function(poi)
        return poi.LocationId == claimedData.poiId
    end)

    if not claimedPoi then
        print("[EventPlanner] ERROR: Could not find claimed POI " .. claimedData.poiId)
        return {}
    end

    -- 2. Create clone POI with offset (bypass queue coordination)
    local clonePoi = self:CreateInteractionClone(claimedPoi, Vector3(-0.7, -0.7, 0))
    claimedData.clonePoi = clonePoi

    -- Register clone POI with POICoordinator for tracking
    if CURRENT_STORY.PoiCoordinator then
        CURRENT_STORY.PoiCoordinator:RegisterClonePOI(clonePoi)
    end

    if DEBUG then
        print(string.format("[EventPlanner] Second actor uses clone POI for interaction: clonePoi.LocationId='%s', original='%s'",
            tostring(clonePoi.LocationId),
            tostring(claimedPoi.LocationId)))
    end

    -- 3. Create action chain: Move (if needed) + Wait
    if self:NeedsMove(actor, clonePoi) then
        local moveAction = self:CreateArtificialMove(actor, clonePoi, event)
        if moveAction then
            -- Mark as interaction action for POICoordinator
            moveAction.relationId = relationId
            moveAction.isInteraction = true
            moveAction.primaryPoiId = claimedData.poiId  -- Reference primary POI, not clone
            table.insert(actions, moveAction)
        end
    end

    -- Create Wait action (doNothing = true for second actor)
    local otherActor = self:GetOtherActorInInteraction(event, actor)
    local waitAction = Wait {
        performer = actor,
        nextLocation = clonePoi,
        targetItem = otherActor,
        targetInteraction = relationId,
        doNothing = true,
        time = 10000000
    }
    -- Mark as interaction action for POICoordinator
    waitAction.relationId = relationId
    waitAction.isInteraction = true
    waitAction.primaryPoiId = claimedData.poiId  -- Reference primary POI, not clone
    table.insert(actions, waitAction)

    -- Update actor state
    local actorId = actor:getData('id')
    local oldLocation = self.actorLocations[actorId]
    self.actorLocations[actorId] = clonePoi.LocationId

    if DEBUG then
        print(string.format("[PlanSecondActorInteraction] Updated actorLocations for %s: '%s' → '%s'",
            actorId,
            tostring(oldLocation),
            tostring(clonePoi.LocationId)))
    end

    return actions
end

--- Plan move action.
--- Flow 4: Move events (explicit or artificial).
---
--- @param actor Player The actor
--- @param event table The event
--- @param segmentId number The temporal segment ID
--- @return table Array of planned actions
function EventPlanner:PlanMoveAction(actor, event, segmentId)
    if DEBUG then
        print("[EventPlanner] PlanMoveAction for event: " .. (event.id or 'unknown'))
    end

    local actorId = actor:getData('id')

    -- 1. Parse target type (location/actor/object)
    local targetType, targetId = self:ParseMoveTarget(event)

    -- 2. Create move action based on target type
    local moveAction = nil

    if targetType == 'location' then
        moveAction = self:CreateLocationMove(actor, targetId, event)
    elseif targetType == 'actor' then
        moveAction = self:CreateActorFollowMove(actor, targetId, event)
    elseif targetType == 'object' then
        moveAction = self:CreateObjectMove(actor, targetId, event)
    end

    if not moveAction then
        print("[EventPlanner] ERROR: Could not create move action for event " .. event.id)
        return {}
    end

    -- 3. Update actor location
    if moveAction.NextLocation and moveAction.NextLocation.LocationId then
        self.actorLocations[actorId] = moveAction.NextLocation.LocationId
    end

    if DEBUG then
        print("[EventPlanner] Planned move action for actor: " .. actorId)
    end

    return {moveAction}
end

--
-- HELPER FUNCTIONS
--

--- Get location candidates for an event
---
--- @param event table The event
--- @param actor Player The actor
--- @return table Array of candidate POIs
function EventPlanner:GetLocationCandidates(event, actor)
    local candidates = {}
    local actorId = actor:getData('id')
    local playerChainId = actor:getData('mappedChainId')

    if DEBUG then
        print(string.format("[GetLocationCandidates] ENTRY: event=%s, actor=%s, actor.chainId=%s",
            event.id or "unknown", actorId or "unknown", tostring(playerChainId)))
    end

    -- Check if event has pre-mapped POIs
    if self.poiMap and self.poiMap[event.id] then
        if DEBUG then
            print(string.format("[GetLocationCandidates] Event has %d pre-mapped POI entries in poiMap",
                #self.poiMap[event.id]))
        end

        -- Track which POI objects we've seen to detect overwrites
        local seenPOIs = {}

        -- Use mapped locations
        for idx, mappedTuple in ipairs(self.poiMap[event.id]) do
            local poi = FirstOrDefault(self.metaEpisode.POI, function(p)
                return p.LocationId == mappedTuple.value
            end)
            if poi then
                -- Track if this is the same POI object as previous iterations
                local poiLocationId = poi.LocationId
                local isRepeat = seenPOIs[poiLocationId] ~= nil

                if DEBUG then
                    print(string.format("[GetLocationCandidates] Loop iteration %d: mappedTuple.locationId=%s, mappedTuple.chainId=%s, poi.LocationId=%s, poiLocationId=%s, isRepeatPOI=%s",
                        idx, tostring(mappedTuple.value), tostring(mappedTuple.chainId),
                        poi.LocationId, poiLocationId, tostring(isRepeat)))
                end

                -- Get current chainId before overwriting
                local oldChainId = poi:getData("mappedChainId_" .. event.id)

                -- Set new chainId (this OVERWRITES if called multiple times on same POI)
                poi:setData("mappedChainId_" .. event.id, mappedTuple.chainId)

                if DEBUG and isRepeat then
                    print(string.format("[GetLocationCandidates] WARNING: Overwriting chainId on same POI object! old=%s, new=%s",
                        tostring(oldChainId), tostring(mappedTuple.chainId)))
                end

                seenPOIs[poiLocationId] = (seenPOIs[poiLocationId] or 0) + 1
                table.insert(candidates, poi)
            end
        end

        if DEBUG then
            -- Report overwrite statistics
            local overwriteCount = 0
            local uniquePOICount = 0
            for poiId, count in pairs(seenPOIs) do
                uniquePOICount = uniquePOICount + 1
                if count > 1 then
                    print(string.format("[GetLocationCandidates] POI object %s was processed %d times (overwrites occurred)", poiId, count))
                    overwriteCount = overwriteCount + 1
                end
            end
            print(string.format("[GetLocationCandidates] Candidates before chainId filter: %d, unique POI objects: %d, overwritten POIs: %d",
                #candidates, uniquePOICount, overwriteCount))
        end

        -- Filter by chain ID (object-specific with fallback to actor's chain)
        -- Get actor's chain ID for regular chain continuity
        local actorChainId = actor:getData('mappedChainId')
        local objectChainId = nil

        -- Check if event uses a picked object with stored chainId
        -- Use objectMap to translate concrete ObjectId → graph object ID
        local graphObjectId = event.Entities and event.Entities[2] or nil
        local pickedObjects = actor:getData('pickedObjects') or {}
        local objectMap = self.story.objectMap

        if graphObjectId and type(pickedObjects) == 'table' and objectMap then
            for _, pickedObj in ipairs(pickedObjects) do
                local pickedConcreteId = pickedObj[1]
                local pickedChainId = pickedObj[3]  -- chainId stored during pickup
                local mappings = objectMap[pickedConcreteId]

                if mappings then
                    for _, mapping in ipairs(mappings) do
                        if mapping.value == graphObjectId then
                            -- Found match: this picked object corresponds to the event's graph object
                            -- Use chainId from pickedObjects (already has the correct one)
                            objectChainId = pickedChainId
                            if DEBUG then
                                print(string.format("[GetLocationCandidates] Found picked object match: concreteId=%s → graphId=%s, chainId=%s",
                                    tostring(pickedConcreteId), tostring(graphObjectId), tostring(objectChainId)))
                            end
                            break
                        end
                    end
                end

                if objectChainId then break end
            end
        end

        -- Use object's chainId if available, otherwise actor's chainId
        local filterChainId = objectChainId or actorChainId

        if filterChainId then
            local beforeCount = #candidates
            candidates = Where(candidates, function(poi)
                local poiChainId = poi:getData("mappedChainId_" .. event.id)
                local matches = poiChainId == filterChainId
                if DEBUG and not matches then
                    print(string.format("[GetLocationCandidates] Filtering out POI %s: chainId=%s != filterChainId=%s",
                        poi.LocationId, tostring(poiChainId), tostring(filterChainId)))
                end
                return matches
            end)
            if DEBUG then
                print(string.format("[GetLocationCandidates] After chainId filter: %d candidates (filtered out %d)",
                    #candidates, beforeCount - #candidates))
            end
        elseif DEBUG then
            print("[GetLocationCandidates] No chainId filter applied (actor has no chain assigned)")
        end
    else
        -- Find candidates dynamically based on region and action
        local targetRegion = event.Location and event.Location[1] or ""
        if DEBUG then
            print(string.format("[GetLocationCandidates] No poiMap for event %s, using dynamic search for region=%s, action=%s",
                event.id, targetRegion, event.Action or "unknown"))
        end
        candidates = Where(self.metaEpisode.POI, function(poi)
            local regionMatch = poi.Region and poi.Region.name:lower():find(targetRegion:lower())
            local hasAction = Any(poi.allActions, function(action)
                return action.Name:lower() == event.Action:lower()
            end)
            return regionMatch and hasAction
        end)
    end

    -- Filter out POIs where object is already taken by another actor
    -- This prevents the "drink hijacking" bug where a displaced actor loses their drink
    -- to another actor who picks up from the same POI
    if event.Action and event.Action:lower() == 'pickup' then
        local beforeTakenFilter = #candidates
        candidates = Where(candidates, function(poi)
            local takenByActor = poi:getData('objectTakenByActor')
            if takenByActor and takenByActor ~= actorId then
                if DEBUG then
                    print(string.format("[GetLocationCandidates] Filtering out POI %s: object already taken by actor %s",
                        poi.LocationId, tostring(takenByActor)))
                end
                return false
            end
            return true
        end)
        if DEBUG and beforeTakenFilter ~= #candidates then
            print(string.format("[GetLocationCandidates] After objectTakenByActor filter: %d candidates (filtered out %d)",
                #candidates, beforeTakenFilter - #candidates))
        end
    end

    if DEBUG then
        local locationIds = {}
        for _, poi in ipairs(candidates) do
            table.insert(locationIds, poi.LocationId)
        end
        print(string.format("[GetLocationCandidates] RETURN: %d candidates [%s]",
            #candidates, table.concat(locationIds, ", ")))
    end

    return candidates
end

--- Filter candidates by spatial constraints
---
--- @param candidates table Array of POI candidates
--- @param event table The event
--- @return table Filtered candidates
function EventPlanner:FilterCandidatesBySpatialConstraints(candidates, event)
    -- Only apply spatial filtering for non-interaction events with objects
    if #event.Entities < 2 or self:IsInteractionEvent(event) then
        return candidates
    end

    local eventObjectId = event.Entities[2]
    local spatialConstraints = self.story.SpatialCoordinator:GetSpatialConstraints(eventObjectId)

    -- No constraints means all candidates are valid
    if not spatialConstraints or #spatialConstraints == 0 then
        return candidates
    end

    local materializedObjects = CURRENT_STORY.materializedObjects or {}

    if DEBUG then
        print("[EventPlanner] Filtering " .. #candidates .. " candidates by spatial constraints for object " .. eventObjectId)
    end

    -- Filter based on spatial constraints
    local filteredCandidates = Where(candidates, function(candidatePoi)
        -- Get the object ID for this candidate
        local chainId = candidatePoi:getData("mappedChainId_" .. event.id)
        local candidateObjectId = candidatePoi:GetMappedEventObjectId(eventObjectId, chainId)

        if candidateObjectId == 'spawnable' then
            -- Spawnable objects don't have fixed positions, skip spatial validation
            return true
        end

        -- Reject if this candidate uses the same physical object as any spatially-related materialized object
        -- Spatial relations (near, left, right, in_front, behind) all imply DIFFERENT objects
        for _, relation in ipairs(spatialConstraints) do
            local targetGraphObjId = relation.target
            local materialized = materializedObjects[targetGraphObjId]

            if materialized and materialized.physicalObjectId and materialized.physicalObjectId == candidateObjectId then
                if DEBUG then
                    print(string.format("[EventPlanner] Rejecting POI %s: same physical object %s as materialized %s",
                        candidatePoi.LocationId or "unknown",
                        candidateObjectId,
                        targetGraphObjId))
                end
                return false
            end
        end

        -- Find the object in the episode
        local candidateObject = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o)
            return o.ObjectId == candidateObjectId
        end)

        if not candidateObject or not candidateObject.position then
            if DEBUG then
                print("[EventPlanner] No object found for " .. tostring(eventObjectId) .. " at POI " .. (candidatePoi.Description or "unknown"))
            end
            return false
        end

        -- Validate spatial constraints (distance/direction checks)
        local isValid, reason = CURRENT_STORY.SpatialCoordinator:ValidateAllConstraints(
            eventObjectId,
            candidateObject.position,
            candidateObject.rotation,
            materializedObjects
        )

        if not isValid and DEBUG then
            print("[EventPlanner] POI " .. (candidatePoi.Description or "unknown") .. " rejected: " .. (reason or "constraint violation"))
        end

        return isValid
    end)

    if DEBUG then
        print("[EventPlanner] After spatial filtering: " .. #filteredCandidates .. " / " .. #candidates .. " candidates remain")
    end

    return filteredCandidates
end

--- Filter candidates by chain conflicts (segment-aware)
---
--- Only blocks POIs where another actor in the SAME segment has the chainId.
--- Actors in different segments can safely share the same chainId (sequential execution).
---
--- @param candidates table Array of POI candidates
--- @param actor Player The actor
--- @param event table The event
--- @param segmentId number The segment ID of the current event
--- @return table Filtered candidates
function EventPlanner:FilterByChainConflicts(candidates, actor, event, segmentId)
    local actorId = actor:getData('id')

    -- Get chain IDs assigned to other actors IN THE SAME SEGMENT
    local otherActorChainIds = {}
    for _, ped in ipairs(self.metaEpisode.peds) do
        local otherId = ped:getData('id')
        if otherId ~= actorId then
            -- Check if other actor's next event is in the same segment
            local otherNextEventId = self.actorNextEvents[otherId]
            local otherSegment = otherNextEventId and self.eventToSegment[otherNextEventId]

            -- Only consider chain conflict if in SAME segment
            if otherSegment == segmentId then
                local otherChainId = ped:getData('mappedChainId')
                if otherChainId then
                    otherActorChainIds[otherChainId] = true
                    if DEBUG then
                        print(string.format("[FilterByChainConflicts] Actor %s blocks chainId %s (same segment %d)",
                            otherId, otherChainId, segmentId))
                    end
                end
            end
        end
    end

    -- Filter out POIs with conflicting chain IDs
    return Where(candidates, function(poi)
        local poiChainId = poi:getData("mappedChainId_" .. event.id)
        return not otherActorChainIds[poiChainId]
    end)
end

--- Get action from location for event
---
--- @param location Location The location
--- @param event table The event
--- @param actor Player The actor
--- @return table|nil The action instance
function EventPlanner:GetActionFromLocation(location, event, actor)
    -- Find action in location that matches event
    local action = FirstOrDefault(location.allActions, function(a)
        return a.Name:lower() == event.Action:lower()
    end)

    if not action then
        return nil
    end

    -- Set performer (only change from template)
    action.Performer = actor

    return action
end

--- Create artificial move action between locations
---
--- @param actor Player The actor
--- @param targetLocation Location The target location
--- @param nextEvent table The next event (for interaction offset)
--- @return table|nil The move action
function EventPlanner:CreateArtificialMove(actor, targetLocation)
    local moveAction = Move {
        performer = actor,
        targetItem = targetLocation,
        nextLocation = targetLocation
    }

    -- Mark as artificial
    moveAction.isArtificial = true

    return moveAction
end

--- Get or create spawnable object
---
--- @param event table The event
--- @param actor Player The actor
--- @return table|nil The spawnable object instance
function EventPlanner:GetOrCreateSpawnableObject(event, actor)
    if #event.Entities < 2 then
        return nil
    end

    local objectType = self.story.graph[event.Entities[2]].Properties.Type
    local inventoryType = objectType:lower()
    local slotNumber = PedHandler:HasInInventory(actor, inventoryType)

    if not slotNumber then
        return nil
    end

    -- Check if already instantiated
    local existingInstance = PedHandler:GetInventoryInstance(actor, slotNumber)
    if existingInstance then
        return existingInstance
    end

    -- Create new instance for TakeOut action
    if event.Action == 'TakeOut' then
        local x, y, z = getElementPosition(actor)
        local rx, ry, rz = getElementRotation(actor)
        local actorId = actor:getData('id')

        local objectInstance = nil

        if inventoryType == "mobilephone" then
            objectInstance = MobilePhone({
                modelid = MobilePhone.eModel.MobilePhone1,
                position = {x=x, y=y, z=z},
                rotation = {x=rx, y=ry, z=rz},
                interior = actor:getInterior()
            })
        elseif inventoryType == "cigarette" then
            objectInstance = Cigarette({
                modelid = Cigarette.eModel.Cigarette1,
                position = {x=x, y=y, z=z},
                rotation = {x=rx, y=ry, z=rz},
                interior = actor:getInterior()
            })
        end

        if objectInstance then
            objectInstance.ObjectId = 'spawnable_' .. inventoryType .. '_' .. actorId
        end

        return objectInstance
    end

    return nil
end

--- Get target for observation action.
--- Finds the target object or actor from episode without changing chains.
---
--- @param event table The event
--- @param actor Player The actor performing observation
--- @return table|userdata|nil The target element (object or ped)
function EventPlanner:GetObservationTarget(event, actor)
    if #event.Entities < 2 then
        return nil
    end

    local targetId = event.Entities[2]

    -- Check if target is an actor
    local targetActor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped)
        return ped:getData('id') == targetId
    end)

    if targetActor then
        if DEBUG then
            print("[EventPlanner] Observation target is actor: " .. targetId)
        end
        return targetActor
    end

    -- Target is an object - find from eventObjectMap using any existing chain
    local eventObjectMap = self.story.eventObjectMap
    if not eventObjectMap or not eventObjectMap[targetId] then
        print("[EventPlanner] ERROR: No eventObjectMap entry for observation target " .. targetId)
        return nil
    end

    -- Use first available chain mapping (observation doesn't care which chain)
    local firstMapping = eventObjectMap[targetId][1]
    if not firstMapping or firstMapping.value == 'spawnable' then
        print("[EventPlanner] ERROR: No valid object mapping for observation target " .. targetId)
        return nil
    end

    local objectId = firstMapping.value

    -- Find object in episode
    local targetObject = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(obj)
        return obj.ObjectId == objectId
    end)

    if not targetObject then
        print("[EventPlanner] ERROR: Object " .. objectId .. " not found in episode for observation target " .. targetId)
        return nil
    end

    if DEBUG then
        print("[EventPlanner] Observation target found: " .. targetId .. " -> " .. objectId)
    end

    return targetObject
end

--- Get interaction candidates
---
--- @param event table The event
--- @param actor Player The actor
--- @return table Array of interaction POI candidates
function EventPlanner:GetInteractionCandidates(event, actor)
    local targetRegion = event.Location and event.Location[1] or ""

    return Where(self.metaEpisode.POI, function(poi)
        local regionMatch = poi.Region and poi.Region.name:lower():find(targetRegion:lower())
        local isInteractionPoi = poi.interactionsOnly == true
        return regionMatch and isInteractionPoi
    end)
end

--- Get other actor in interaction
---
--- @param event table The interaction event
--- @param actor Player The current actor
--- @return Player|nil The other actor
function EventPlanner:GetOtherActorInInteraction(event, actor)
    if #event.Entities < 2 then
        return nil
    end

    local actorId = actor:getData('id')
    local otherActorId = event.Entities[1] == actorId and event.Entities[2] or event.Entities[1]

    return FirstOrDefault(self.metaEpisode.peds, function(ped)
        return ped:getData('id') == otherActorId
    end)
end

--- Create interaction action
---
--- @param event table The interaction event
--- @param actor Player The actor
--- @param location Location The interaction location
--- @param otherActor Player The other actor
--- @return table|nil The interaction action
function EventPlanner:CreateInteractionAction(event, actor, location, otherActor)
    local actionName = event.Action

    if actionName == 'HandShake' or actionName == 'Handshake' then
        return HandShake {
            performer = actor,
            nextLocation = location,
            targetPlayer = otherActor,
            targetItem = otherActor,
            time = random(6000, 15000)
        }
    elseif actionName == 'Kiss' then
        return Kiss {
            performer = actor,
            nextLocation = location,
            targetPlayer = otherActor,
            targetItem = otherActor,
            time = random(6000, 15000)
        }
    elseif actionName == 'Hug' then
        return Hug {
            performer = actor,
            nextLocation = location,
            targetPlayer = otherActor,
            targetItem = otherActor,
            time = random(6000, 15000)
        }
    elseif actionName == 'Talk' then
        return Talk {
            performer = actor,
            nextLocation = location,
            targetPlayer = otherActor,
            targetItem = otherActor,
            time = random(6000, 15000)
        }
    elseif actionName == 'Laugh' then
        return Laugh {
            performer = actor,
            nextLocation = location,
            targetPlayer = otherActor,
            targetItem = otherActor,
            time = random(6000, 15000)
        }
    elseif actionName == 'Give' then
        return Give {
            performer = actor,
            nextLocation = location,
            targetPlayer = otherActor,
            targetItem = otherActor,
            time = random(6000, 15000)
        }
    elseif actionName == 'Receive' or actionName == 'INV-Give' then
        return Receive {
            performer = actor,
            nextLocation = location,
            targetPlayer = otherActor,
            targetItem = otherActor,
            time = random(6000, 15000)
        }
    end

    return nil
end

--- Find location by ID, checking both metaEpisode.POI and clone POIs.
--- Clone POIs are created dynamically for interactions and stored in interactionPoiMap.
---
--- @param locationId string The location ID to find
--- @return Location|nil The location object, or nil if not found
function EventPlanner:FindLocationById(locationId)
    -- 1. Check metaEpisode.POI first (original POIs)
    local location = FirstOrDefault(self.metaEpisode.POI, function(poi)
        return poi.LocationId == locationId
    end)

    if location then
        return location
    end

    -- 2. Check clone POIs (only if locationId ends with "_clone")
    if locationId and locationId:match("_clone$") then
        for relationId, claimedData in pairs(self.interactionPoiMap) do
            if claimedData.clonePoi and claimedData.clonePoi.LocationId == locationId then
                return claimedData.clonePoi
            end
        end
    end

    return nil
end

--- Create interaction clone POI
---
--- @param originalLocation Location The original POI
--- @param offset Vector3 The position offset
--- @return Location The cloned POI
function EventPlanner:CreateInteractionClone(originalLocation, offset)
    offset = offset or Vector3(-0.7, -0.7, 0)

    local clone = Location(
        originalLocation.X + offset.x,
        originalLocation.Y + offset.y,
        originalLocation.Z + offset.z,
        originalLocation.Angle,
        originalLocation.Interior,
        originalLocation.Description .. "_clone",
        originalLocation.Region,
        false,  -- compact = false so position is Vector3, not table
        nil,   -- log
        originalLocation.episodeLinks
    )
    clone.isBusy = false
    clone.allActions = originalLocation.allActions
    clone.PossibleActions = originalLocation.PossibleActions  -- Enable displacement from clone POIs
    clone.LocationId = originalLocation.LocationId .. "_clone"
    clone.originalLocationId = originalLocation.LocationId  -- Reference for debugging
    clone.interactionsOnly = originalLocation.interactionsOnly
    clone.isClone = true
    clone.Episode = originalLocation.Episode
    clone.Region = originalLocation.Region

    return clone
end

--- Parse move target from event
---
--- @param event table The move event
--- @return string, string Target type and target ID
function EventPlanner:ParseMoveTarget(event)
    if #event.Entities < 2 then
        -- Location-based move
        return 'location', event.Location and event.Location[2] or event.Location[1]
    end

    local targetEntityId = event.Entities[2]
    local targetEntity = self.story.graph[targetEntityId]

    if targetEntity.Properties and targetEntity.Properties.Gender then
        return 'actor', targetEntityId
    else
        return 'object', targetEntityId
    end
end

--- Create location-based move
---
--- @param actor Player The actor
--- @param targetRegionName string The target region name
--- @param event table The move event
--- @return table|nil The move action
function EventPlanner:CreateLocationMove(actor, targetRegionName, event)
    local actorId = actor:getData('id')

    -- 1. Get ALL POIs in target region
    local candidates = Where(self.metaEpisode.POI, function(poi)
        return poi.Region and poi.Region.name:lower():find(targetRegionName:lower())
    end)

    if #candidates == 0 then
        print("[CreateLocationMove] ERROR: No POIs found in region " .. targetRegionName)
        return nil
    end

    -- 2. Filter out busy POIs
    local availableCandidates = Where(candidates, function(poi)
        return not poi.isBusy
    end)

    -- Fall back to all candidates if none available (will overlap but won't fail)
    if #availableCandidates == 0 then
        availableCandidates = candidates
        if DEBUG then
            print("[CreateLocationMove] WARNING: All POIs busy in " .. targetRegionName .. ", allowing overlap")
        end
    end

    -- 3. Get segment ID for collision scoring
    local segmentId = self:EnsureTemporalSegmentComputed(event)

    -- 4. Use collision scoring to select best POI
    local targetPoi = self:SelectLowestCollisionPOI(availableCandidates, segmentId)

    if not targetPoi then
        print("[CreateLocationMove] ERROR: Could not select POI in " .. targetRegionName)
        return nil
    end

    -- 5. Track POI usage for subsequent actors
    self:TrackPOIUsage(segmentId, targetPoi.LocationId, actorId)

    if DEBUG then
        print("[CreateLocationMove] Actor " .. actorId .. " moving to " ..
              (targetPoi.Description or targetPoi.LocationId))
    end

    return Move {
        performer = actor,
        targetItem = targetPoi,
        nextLocation = targetPoi
    }
end

--- Create actor-following move
---
--- @param actor Player The actor
--- @param targetActorId string The target actor ID
--- @param event table The move event
--- @return table|nil The move action
function EventPlanner:CreateActorFollowMove(actor, targetActorId, event)
    local targetActor = FirstOrDefault(self.metaEpisode.peds, function(ped)
        return ped:getData('id') == targetActorId
    end)

    if not targetActor then
        return nil
    end

    -- Create move with entity tracking
    return Move {
        performer = actor,
        targetItem = targetActor,
        targetEntity = targetActor,
        entityType = 'actor',
        actualTargetEntityId = targetActorId
    }
end

--- Create object-tracking move
---
--- @param actor Player The actor
--- @param targetObjectId string The target object ID
--- @param event table The move event
--- @return table|nil The move action
function EventPlanner:CreateObjectMove(actor, targetObjectId, event)
    -- Check if object is held by another actor
    local holdingActor = FirstOrDefault(self.metaEpisode.peds, function(ped)
        local pickedObjects = ped:getData('pickedObjects')
        if not pickedObjects or #pickedObjects == 0 then
            return false
        end
        return Any(pickedObjects, function(po)
            return po[1] == targetObjectId
        end)
    end)

    if holdingActor then
        -- Object is held - convert to actor-based move
        return self:CreateActorFollowMove(actor, holdingActor:getData('id'), event)
    else
        -- Object not held - find POI where object is located
        local objectPoi = FirstOrDefault(self.metaEpisode.POI, function(poi)
            return Any(poi.allActions, function(action)
                return action.TargetItem and
                       action.TargetItem.ObjectId == targetObjectId
            end)
        end)

        if not objectPoi then
            return nil
        end

        return Move {
            performer = actor,
            targetItem = objectPoi,
            nextLocation = objectPoi,
            entityType = 'object',
            actualTargetEntityId = targetObjectId
        }
    end
end

--- Select POI with lowest collision score within segment.
---
--- @param candidates table Array of candidate POIs
--- @param segmentId number The temporal segment ID
--- @param actorId string The actor making the selection (to exclude self from collision check)
--- @return Location The selected POI (or nil if no candidates)
function EventPlanner:SelectLowestCollisionPOI(candidates, segmentId, actorId)
    if not candidates or #candidates == 0 then
        return nil
    end

    -- Score each candidate
    local scored = {}
    for _, poi in ipairs(candidates) do
        local score = 0

        -- Check if POI already used by a DIFFERENT actor in this segment
        if self.segmentPOIUsage[segmentId] then
            local existingActor = self.segmentPOIUsage[segmentId][poi.LocationId]
            if existingActor and existingActor ~= actorId then
                score = score + 100  -- Collision penalty only for DIFFERENT actor
            end
        end

        table.insert(scored, { poi = poi, score = score })
    end

    -- Sort by score (lower is better)
    table.sort(scored, function(a, b) return a.score < b.score end)

    if DEBUG_VALIDATION then
        print("[EventPlanner] Selected POI with score: " .. scored[1].score ..
              " for actor " .. tostring(actorId) .. " (collisions allowed if no other option)")
    end

    return scored[1].poi
end

--- Track POI usage in segment for collision minimization.
---
--- @param segmentId number The temporal segment ID
--- @param poiId string The POI location ID
--- @param actorId string The actor using the POI
function EventPlanner:TrackPOIUsage(segmentId, poiId, actorId)
    if not self.segmentPOIUsage[segmentId] then
        self.segmentPOIUsage[segmentId] = {}
    end

    self.segmentPOIUsage[segmentId][poiId] = actorId

    if DEBUG_VALIDATION then
        print("[EventPlanner] Tracked POI usage: segment=" .. segmentId ..
              ", poi=" .. poiId .. ", actor=" .. actorId)
    end
end

--- Check if actor needs to move to target location.
---
--- @param actor Player The actor
--- @param targetLocation Location The target location
--- @return boolean True if move needed
function EventPlanner:NeedsMove(actor, targetLocation)
    local actorId = actor:getData('id')
    local currentLocationId = self.actorLocations[actorId]

    if not currentLocationId then
        -- No current location, move needed
        if DEBUG then
            print(string.format("[NeedsMove] Actor %s has no current location → MOVE NEEDED", actorId))
        end
        return true
    end

    if not targetLocation or not targetLocation.LocationId then
        if DEBUG then
            print(string.format("[NeedsMove] Actor %s - invalid target location → NO MOVE", actorId))
        end
        return false
    end

    local targetLocationId = targetLocation.LocationId

    -- Check if same location
    local isSameArea = currentLocationId == targetLocationId

    if not isSameArea then
        -- Check if one is clone of the other (e.g., "22_garden" and "22_garden_clone")
        if currentLocationId and targetLocationId then
            local currentBase = currentLocationId:gsub("_clone$", "")
            local targetBase = targetLocationId:gsub("_clone$", "")

            if currentBase == targetBase then
                -- Same base POI - but ONLY treat as "same area" if actor is
                -- already in an active interaction at this POI
                -- This allows follow-up interactions to skip unnecessary moves
                -- while requiring moves for pre-interaction arrivals
                if CURRENT_STORY and CURRENT_STORY.PoiCoordinator then
                    local isInInteraction = CURRENT_STORY.PoiCoordinator:IsActorInInteraction(
                        currentLocationId, actorId)
                    if isInInteraction then
                        isSameArea = true
                        if DEBUG then
                            print(string.format("[NeedsMove] Actor %s already in interaction at %s, treating as same area",
                                actorId, currentBase))
                        end
                    end
                end
            end
        end
    end

    local needsMove = not isSameArea
    if DEBUG then
        print(string.format("[NeedsMove] Actor %s: current='%s', target='%s' → %s",
            actorId,
            tostring(currentLocationId),
            tostring(targetLocationId),
            needsMove and "MOVE NEEDED" or "NO MOVE"))
    end
    return needsMove
end

if DEBUG then
    print("[EventPlanner] EventPlanner module loaded")
end
