ActionsOrchestrator = class(function(o, eventBus)
    o.eventRequests = {
        -- actorId: {eventId, actor, actions (array, nil until planned), constraints = {{actorId, eventId, kind}, ...}, planned = false }
    }
    o.fulfilled = {}
    o.actionQueue = {}
    o.poiQueues = {}  -- Per-POI execution queues: { [locationId] = { {actor, action, eventId}, ... } }
    o.lock = false
    o.EventBus = eventBus or EventBus:getInstance()
    o.currentSegment = nil  -- Track current active segment for sequential execution
end)

function ActionsOrchestrator:Reset()
    self.eventRequests = {}
    self.actionQueue = {}
    self.poiQueues = {}
    self.fulfilled = {}
    self.lock = false
    self.currentSegment = nil
end

--- Initialize ActionsOrchestrator with EventBus subscriptions.
--- Called after story creation to set up event listeners.
function ActionsOrchestrator:Initialize()
    if self.EventBus then
        self.EventBus:subscribe("graph_event_end", "actions_orchestrator", function(eventData)
            self:onGraphEventEnd(eventData)
        end)

        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[ActionsOrchestrator] Subscribed to graph_event_end")
        end
    end
end

--- Handle graph event end to mark events as fulfilled.
--- @param eventData table {eventId, actorId, actionName}
function ActionsOrchestrator:onGraphEventEnd(eventData)
    if not eventData or not eventData.eventId then
        return
    end

    -- Mark event as fulfilled
    table.insert(self.fulfilled, eventData.eventId)

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[ActionsOrchestrator] Event fulfilled: "..eventData.eventId.." (total fulfilled: "..#self.fulfilled..")")
    end

    -- Validate constraints for all actors now that fulfillment state changed
    -- This triggers other actors whose constraints are now satisfied
    self:ProcessAndValidateConstraints()
end

--- Process and validate constraints for all pending event requests.
--- Wrapper for ProcessEventRequests to provide semantic clarity.
function ActionsOrchestrator:ProcessAndValidateConstraints()
    self:ProcessEventRequests()
end

---Enqueues an event for planning and execution in graph-based orchestration.
---This is the primary entry point for EventPlanner integration.
---@param actor table The actor performing the event
---@param eventId string The graph event ID to enqueue
function ActionsOrchestrator:EnqueueEvent(actor, eventId)
    local actorId = actor:getData('id')
    local existingRequest = self.eventRequests[actorId]

    -- DIAGNOSTIC: Check if we're about to overwrite a request with pendingGraphAction
    if DEBUG then
        if existingRequest then
            print(string.format("[DIAG][EnqueueEvent] Actor %s: existing request eventId=%s, pendingGraphAction=%s, new eventId=%s",
                actorId,
                tostring(existingRequest.eventId),
                existingRequest.pendingGraphAction and existingRequest.pendingGraphAction.Name or "nil",
                eventId))
        else
            print(string.format("[DIAG][EnqueueEvent] Actor %s: no existing request, creating new for eventId=%s", actorId, eventId))
        end
    end

    -- FIX 9: Don't overwrite if existing request has pendingGraphAction (starts_with sync point)
    if existingRequest and existingRequest.pendingGraphAction then
        if DEBUG then
            print(string.format("[EnqueueEvent] Actor %s has pendingGraphAction (%s), triggering re-check instead of overwriting",
                actorId, existingRequest.pendingGraphAction.Name))
        end
        self:ProcessEventRequests()  -- Re-check if all actors ready
        return
    end

    CURRENT_STORY.CameraHandler:clearFocusRequests(actor:getData('id'))
    actor:setData('isAwaitingContextSwitch', false)
    actor:setData('isAwaitingConstraints', true)

    local actorEvents = CURRENT_STORY.lastEvents[actor:getData('id')]
    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[EnqueueEvent] actorId ".. actor:getData('id').." - eventId "..eventId.." - last events "..stringifyTable(actorEvents))
    end

    if DEBUG then
        print("[EnqueueEvent] actorId ".. actor:getData('id').." event "..eventId.." - awaiting temporal constraints")
    end

    -- Extract temporal constraints for this event
    local constraints = self:GetTemporalConstraints(actor, nil, eventId)

    -- Store event request (action will be planned when constraints satisfied)
    self.eventRequests[actor:getData('id')] = {
        eventId = eventId,
        actor = actor,
        action = nil,  -- Will be planned later
        constraints = constraints,
        planned = false
    }

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[EnqueueEvent] actorId ".. actor:getData('id').." - constraints "..stringifyTable(constraints))
        print("[EnqueueEvent] fulfilled "..stringifyTable(self.fulfilled))
    end

    self:ProcessEventRequests()
end

---Enqueues an action for the actor. Routes to graph-based or linear orchestration.
---@param action table The action to enqueue
---@param actor table The actor performing the action
---@param eventId string|nil Optional eventId to associate with this action (defaults to lookup from lastEvents)
function ActionsOrchestrator:EnqueueAction(action, actor, eventId)
    CURRENT_STORY.CameraHandler:clearFocusRequests(actor:getData('id'))

    -- If using EventPlanner and action was popped from queue, execute directly without re-validation
    if CURRENT_STORY.eventPlanner and CURRENT_STORY:is_a(GraphStory) then
        local actorId = actor:getData('id')

        -- Check if action needs POI acquisition before execution
        if action.NextLocation then
            local actorLocation = actor:getData('locationId')
            local requiredLocation = action.NextLocation.LocationId

            -- Check if same location OR same interaction area (main and clone are same physical spot)
            local isSameArea = actorLocation == requiredLocation
            if not isSameArea and actorLocation and requiredLocation then
                local currentBase = actorLocation:gsub("_clone$", "")
                local targetBase = requiredLocation:gsub("_clone$", "")
                isSameArea = currentBase == targetBase
            end

            if not isSameArea then
                if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                    print("[EnqueueAction] Actor "..actorId.." at wrong location (at "..tostring(actorLocation)..", needs "..tostring(requiredLocation)..")")
                    if action.NextLocation.isClone then
                        print("[EnqueueAction] This is a cloned interaction POI - will coordinate through queue")
                    end
                end

                -- Set flag to prevent premature queue popping
                actor:setData('pendingPOIAction', true)

                -- Enqueue actor for target POI - queue system will handle displacement and execution
                self:EnqueueForPOI(actor, action, eventId, requiredLocation)
                return
            end
        end

        local request = self.eventRequests[actorId]

        -- If request exists and was already performed (actions were queued), skip EnqueueActionGraph
        if request and request.performed then
            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[EnqueueAction] Action popped from queue, executing directly: "..action.Name)
            end
            self:TriggerActionExecution(actor, action, eventId)
            return
        end

        -- FIX 17: Skip EnqueueActionGraph for re-enqueued actions (kick-off from ValidateAndExecuteGroup)
        -- POI check already happened above, so coordination is preserved
        -- This prevents: overwriting request (losing pendingGraphAction) and recursive ProcessEventRequests calls
        if action._isReenqueue then
            action._isReenqueue = nil  -- Clear flag
            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[EnqueueAction] Re-enqueued action, executing directly: "..action.Name)
            end
            self:TriggerActionExecution(actor, action, eventId)
            return
        end
    end

    if CURRENT_STORY:is_a(GraphStory) then
        self:EnqueueActionGraph(action, actor, eventId)
    else
        self:EnqueueActionLinear(action, actor, eventId)
    end
end

---Enqueues an action in graph-based orchestration with temporal constraint validation.
---DEPRECATED: Kept for backward compatibility. Use EnqueueEvent for EventPlanner flow.
---@param action table The action to enqueue
---@param actor table The actor performing the action
---@param eventId string|nil Optional eventId to associate with this action (defaults to lookup from lastEvents)
function ActionsOrchestrator:EnqueueActionGraph(action, actor, eventId)
    actor:setData('isAwaitingContextSwitch', false)
    actor:setData('isAwaitingConstraints', true)

    local actorEvents = CURRENT_STORY.lastEvents[actor:getData('id')]
    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[EnqueueActionGraph] actorId ".. actor:getData('id').." - last events "..stringifyTable(actorEvents))
    end
    local lastEvent = nil
    if actorEvents and #actorEvents > 0 then
        lastEvent = actorEvents[#actorEvents]
    end

    -- Use provided eventId if available, otherwise fall back to lastEvent.id
    local effectiveEventId = eventId or (lastEvent and lastEvent.id or nil)

    if DEBUG then
        if not lastEvent then
            print("[EnqueueActionGraph] actorId ".. actor:getData('id').." - no last event for action "..action.Name..': '..action:GetDynamicString().." (eventId: "..tostring(effectiveEventId)..")")
        else
            print("[EnqueueActionGraph] actorId ".. actor:getData('id').." event "..lastEvent.id.." - action "..action.Name..': '..action:GetDynamicString().." (eventId: "..tostring(effectiveEventId)..")")
        end
    end

    local constraints = self:GetTemporalConstraints(actor, action, effectiveEventId)
    self.eventRequests[actor:getData('id')] = {
        eventId = effectiveEventId,
        actor = actor,
        actions = {action},  -- Wrap single action in array for consistency with new flow
        constraints = constraints,
        planned = true  -- Action already provided (old flow)
    }

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[EnqueueActionGraph] actorId ".. actor:getData('id').." - constraints "..stringifyTable(constraints))
        print("[EnqueueActionGraph] fulfilled "..stringifyTable(self.fulfilled))
    end

    self:ProcessEventRequests()
end

---Retrieves a list of temporal constraints for the actor and the action. E.g. all the actions that have to be performed before the current action can be performed.
--- possible temporal constraints are:
--- a_n -> after -> b_n (a_n starts after b_n ends, with a potential delay)
--- a_n -> before -> b_n (a _n starts only if b_n has not started yet) ----> When b_n is supposed to start, it should first wait for a_n to finish
---------------
--- a_n <-> starts_with <-> b_n (a_n and b_n start at the same time)           Should be present on all events that start at the same time
--- a_n -> concurent (max_delay) -> b_n (a_n and b_n start in random order with a random max_delay)
---------------
--- meanwhile is an implicit relationship between all events of other actors executed in between two events of the same actor
---------------
--- eg: a:tai_chi  -concurrent-> b:go_to_kitchen -next-> b:get_water -next-> b:go_to_a -next-> b:give_a -same_time-> a:receive_b
---                                   ^------------------------|-meanwhile-------------|-------------------|
--- actions that can be executed meanwhile: tai_chi, eat, drink, smoke, talk_phone, stay_seated, sleep, type_keyboard, workout, cycle
--- option1: execution in a loop that is stopped when next same-actor action is performed, or episode ended
--- problem, TODO: when context is switched, the animations are reset, they have to be re-executed. If the animation changes actor's position, it is reset (e.g. sleep, sit down)
---@param actor any The actor that is supposed to perform the action
---@param action any The action that is supposed to be performed
---@param eventId string The ID of the current event being enqueued
---@return table constraints A list of temporal constraints in the form of {actorId, eventId, kind}, where kind is one of the following: "starts_with", "concurent", "after"
function ActionsOrchestrator:GetTemporalConstraints(actor, action, eventId)
    local constraints = {}
    local actorId = actor:getData('id')
    local temporalData = CURRENT_STORY.temporal[eventId]

    if temporalData then
        if temporalData.relations then
            for _, constraintId in ipairs(temporalData.relations) do
                local constraint = CURRENT_STORY.temporal[constraintId]
                if not constraint then
                    print("[ERROR] [GetTemporalConstraints] actorId ".. actorId.." - constraintId "..constraintId.." not found")
                end
                if constraint.type == 'starts_with' then
                    local linkedConstraints = Where(CURRENT_STORY.temporal, function(tempConstraint)
                        return
                            tempConstraint.key ~= 'starting_actions'
                            and tempConstraint.relations
                            and inList(constraintId, tempConstraint.relations)
                            and CURRENT_STORY.graph[tempConstraint.key].Entities[1] ~= actorId
                        end)
                    for _, linkedConstraint in pairs(linkedConstraints) do
                        table.insert(constraints, {actorId = CURRENT_STORY.graph[linkedConstraint.key].Entities[1], eventId = linkedConstraint.key, constraint = constraint})

                        -- Find the event that is before the linked event, this is needed to enforce the order of the events for interactions, where only the initiator will have a request to execute the event
                        local eventBeforeLinkedStartsWith = FirstOrDefault(CURRENT_STORY.temporal, function(tempConstraint) return tempConstraint.next == linkedConstraint.key end)
                        if eventBeforeLinkedStartsWith then
                            table.insert(constraints, {actorId = CURRENT_STORY.graph[eventBeforeLinkedStartsWith.key].Entities[1], eventId = eventBeforeLinkedStartsWith.key, constraint = {type = 'after', source = temporalData.key, target = eventBeforeLinkedStartsWith.key}})
                        end
                    end
                elseif constraint.type == 'concurent' or constraint.type == 'after' then
                    -- Always extract after/concurrent constraints (even for artificial actions)
                    table.insert(constraints, {actorId = CURRENT_STORY.graph[constraint.target].Entities[1], eventId = constraint.target, constraint = constraint})
                end
            end
        end

        -- Find all the constraints of type before that have the current event as a target
        -- Always extract before constraints (even for artificial actions)
        local beforeConstraints = Where(CURRENT_STORY.temporal, function(tempConstraint) return tempConstraint.type == 'before' and tempConstraint.target == eventId end)

        -- Find the events for which the current event has to wait (other actions that have a before constraint with the current event as a target)
        for _, beforeConstraint in ipairs(beforeConstraints) do
            table.insert(constraints, {actorId = CURRENT_STORY.graph[beforeConstraint.source].Entities[1], eventId = beforeConstraint.source, constraint = beforeConstraint})
        end
    end
    return constraints
end

---Processes event requests: validates temporal constraints, plans actions, coordinates POIs, and executes.
---This is the main orchestration loop for event-based planning with EventPlanner integration.
function ActionsOrchestrator:ProcessEventRequests()
    -- Phase 1: Validate temporal constraints
    self:ValidateSingularConstraints()
    self:ValidateConcurrentConstraints()

    -- Phase 2: Plan actions for events with satisfied constraints (segment-filtered)
    -- Also handles re-planning for displaced actors
    for actorId, request in pairs(self.eventRequests) do
        -- Re-planning path: actor was displaced, need to re-plan navigation
        if request.needsReplanning and request.planned then
            local actor = request.actor
            local eventId = request.eventId

            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[ProcessEventRequests] Re-planning for displaced actor "..actorId.." event "..eventId..
                      " (reason: "..(request.displacementReason or 'unknown')..")")
            end

            -- Get event's segment ID to ensure we're still in correct segment
            local event = CURRENT_STORY.graph[eventId]
            if event and CURRENT_STORY.eventPlanner then
                local eventSegmentId = CURRENT_STORY.eventPlanner:GetSegmentIdForEvent(event)

                -- Only re-plan if event belongs to current segment
                if eventSegmentId == self.currentSegment then
                    -- Re-plan actions from new location
                    local newActions = CURRENT_STORY.eventPlanner:PlanNextAction(actor, eventId)

                    if newActions and #newActions > 0 then
                        request.actions = newActions
                        request.needsReplanning = false
                        request.displacementReason = nil

                        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                            local actionNames = Select(newActions, function(a) return a.Name end)
                            print("[ProcessEventRequests] Re-planned "..#newActions.." action(s) for displaced actor "..
                                  actorId..": "..table.concat(actionNames, ", "))
                        end
                    else
                        print("[ERROR] [ProcessEventRequests] Failed to re-plan actions for displaced actor "..actorId)
                        -- Keep needsReplanning flag to retry next cycle
                    end
                else
                    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        print("[ProcessEventRequests] Displaced actor "..actorId.." event "..eventId..
                              " belongs to segment "..eventSegmentId..", current segment is "..self.currentSegment..
                              " - deferring re-planning")
                    end
                    -- Keep needsReplanning flag for when segment becomes current
                end
            end

        -- Normal planning path: event has satisfied constraints but not yet planned
        elseif request.isValid and not request.planned then
            local actor = request.actor
            local eventId = request.eventId

            -- Get event's segment ID from EventPlanner
            local event = CURRENT_STORY.graph[eventId]
            if event and CURRENT_STORY.eventPlanner then
                local eventSegmentId = CURRENT_STORY.eventPlanner:GetSegmentIdForEvent(event)

                -- Initialize currentSegment from first event
                if not self.currentSegment then
                    self.currentSegment = eventSegmentId
                    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        print("[ProcessEventRequests] Initializing current segment to "..self.currentSegment)
                    end
                end

                -- Only plan events from current segment
                if eventSegmentId == self.currentSegment then
                    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        print("[ProcessEventRequests] Planning for actorId ".. actorId.." event "..eventId.." (segment "..eventSegmentId..")")
                    end

                    -- Call EventPlanner to plan actions for this event
                    local plannedActions = CURRENT_STORY.eventPlanner:PlanNextAction(actor, eventId)

                    if plannedActions and #plannedActions > 0 then
                        -- Store ALL actions (both artificial and main) for coordination
                        request.actions = plannedActions
                        request.planned = true

                        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                            local actionNames = Select(plannedActions, function(a) return a.Name end)
                            local artificialCount = #Where(plannedActions, function(a) return a.isArtificial end)
                            print("[ProcessEventRequests] Planned "..#plannedActions.." action(s) for actorId ".. actorId.." event "..eventId.." ("..artificialCount.." artificial): "..table.concat(actionNames, ", "))
                        end
                    else
                        print("[ERROR] [ProcessEventRequests] EventPlanner failed to plan actions for actorId ".. actorId.." event "..eventId)
                    end
                elseif DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                    print("[ProcessEventRequests] Deferring event "..eventId.." in segment "..eventSegmentId.." (current segment: "..self.currentSegment..")")
                end
            else
                print("[ERROR] [ProcessEventRequests] EventPlanner not initialized for story")
            end
        end
    end

    -- Phase 3: Collect constraint groups that are ready to execute
    local startsWithGroups = self:CollectStartsWithGroups()
    local concurrentGroups = self:CollectConcurrentGroups()

    -- Phase 4: Validate POI availability for constraint groups and execute
    -- ValidateAndExecuteGroup handles marking performed internally when all actors are ready
    for _, group in ipairs(startsWithGroups) do
        self:ValidateAndExecuteGroup(group, "starts_with")
    end

    for _, group in ipairs(concurrentGroups) do
        if self:ValidateAndExecuteGroup(group, "concurrent") then
            -- Mark as performed
            for _, request in ipairs(group) do
                request.performed = true
            end
        end
    end

    -- Phase 5: Execute singular requests (no constraint groups)
    self:ExecuteSingularRequests()

    -- Phase 6: Clean up performed requests (preserve requests flagged for re-planning)
    self.eventRequests = Where(self.eventRequests, function(request)
        return not request.performed or request.needsReplanning
    end)

    -- Phase 7: Process POI queues
    for locationId, queue in pairs(self.poiQueues) do
        if #queue > 0 then
            self:ProcessPOIQueue(locationId)
        end
    end

    -- Phase 8: Check if current segment is complete and advance if needed
    self:CheckSegmentCompletion()
end

--- Check if current segment is complete and advance to next segment if needed.
--- Called after ProcessEventRequests to enable sequential segment execution.
function ActionsOrchestrator:CheckSegmentCompletion()
    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[CheckSegmentCompletion] ENTRY - currentSegment=" .. tostring(self.currentSegment))
    end

    if not self.currentSegment or not CURRENT_STORY.eventPlanner then
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[CheckSegmentCompletion] Early return: currentSegment or eventPlanner nil")
        end
        return
    end

    local currentSegmentData = CURRENT_STORY.eventPlanner.temporalSegments[self.currentSegment]
    if not currentSegmentData then
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[CheckSegmentCompletion] Early return: temporalSegments[" .. self.currentSegment .. "] is nil")
        end
        return
    end

    -- Check if ALL events in current segment are fulfilled (not just enqueued ones)
    local allFulfilled = true
    for _, eventId in ipairs(currentSegmentData.events) do
        if not inList(eventId, self.fulfilled) then
            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[CheckSegmentCompletion] Unfulfilled segment event: " .. eventId)
            end
            allFulfilled = false
            break
        end
    end

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[CheckSegmentCompletion] allFulfilled=" .. tostring(allFulfilled))
    end

    if not allFulfilled then
        return  -- Current segment still has pending enqueued events
    end

    -- Current segment complete - advance to next sequential segment
    -- EventPlanner has already computed all segments sequentially (1, 2, 3, ..., N)
    -- No need to "discover" the next segment - just increment
    local nextSegment = self.currentSegment + 1

    -- Verify segment exists (or story is complete)
    if not CURRENT_STORY.eventPlanner.temporalSegments[nextSegment] then
        nextSegment = nil  -- No more segments, story complete
    end

    if nextSegment then
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[ActionsOrchestrator] Segment "..self.currentSegment.." complete, advancing to segment "..nextSegment)
        end
        self.currentSegment = nextSegment

        -- Trigger planning for next segment
        self:ProcessEventRequests()
    elseif DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[ActionsOrchestrator] Segment "..self.currentSegment.." complete, no more segments")
    end
end

---Collects all starts_with constraint groups that are ready to execute.
---@return table Array of groups, where each group is an array of event requests
function ActionsOrchestrator:CollectStartsWithGroups()
    local groups = {}
    local processed = {}

    for actorId, request in pairs(self.eventRequests) do
        if request.isValid and request.planned and not request.performed and not processed[actorId] then
            local startsWithConstraints = Where(request.constraints,
                function(c) return c.constraint.type == 'starts_with' end)

            -- Skip starts_with coordination if ALL actions are artificial (navigation-only)
            local allArtificial = request.actions and #request.actions > 0 and
                All(request.actions, function(a) return a.isArtificial end)

            if #startsWithConstraints > 0 and not allArtificial then
                -- Collect all actors in this starts_with group
                local group = {request}
                processed[actorId] = true

                for _, constraint in ipairs(startsWithConstraints) do
                    local linkedRequest = self.eventRequests[constraint.actorId]
                    if linkedRequest and linkedRequest.eventId == constraint.eventId and linkedRequest.isValid and linkedRequest.planned and not linkedRequest.performed then
                        table.insert(group, linkedRequest)
                        processed[constraint.actorId] = true
                    end
                end

                table.insert(groups, group)
            end
        end
    end

    return groups
end

---Collects all concurrent constraint groups that are ready to execute.
---@return table Array of groups, where each group is an array of event requests
function ActionsOrchestrator:CollectConcurrentGroups()
    local groups = {}
    local processed = {}

    for actorId, request in pairs(self.eventRequests) do
        if request.isValid and request.planned and not request.performed and not processed[actorId] then
            local concurrentConstraints = Where(request.constraints,
                function(c) return c.constraint.type == 'concurent' end)

            if #concurrentConstraints > 0 then
                -- Collect all actors in this concurrent group
                local group = {request}
                processed[actorId] = true

                for _, constraint in ipairs(concurrentConstraints) do
                    local linkedRequest = self.eventRequests[constraint.actorId]
                    if linkedRequest and linkedRequest.eventId == constraint.eventId and linkedRequest.isValid and linkedRequest.planned and not linkedRequest.performed then
                        table.insert(group, linkedRequest)
                        processed[constraint.actorId] = true

                        -- Capture max_delay from constraint
                        if constraint.constraint.max_delay then
                            linkedRequest.max_delay = constraint.constraint.max_delay
                        end
                    end
                end

                table.insert(groups, group)
            end
        end
    end

    return groups
end

---Validates POI availability for a constraint group and executes if successful.
---@param group table Array of event requests in the constraint group
---@param groupType string "starts_with" or "concurrent"
---@return boolean True if group was executed, false if deferred
function ActionsOrchestrator:ValidateAndExecuteGroup(group, groupType)
    if not group or #group == 0 then return false end

    -- Validate group completeness for both starts_with and concurrent
    if groupType == "starts_with" or groupType == "concurrent" then
        for _, request in ipairs(group) do
            local constraintType = groupType == "starts_with" and 'starts_with' or 'concurent'  -- Note: typo is consistent in codebase
            local expectedPartners = #Where(request.constraints,
                function(c) return c.constraint.type == constraintType end)
            if #group ~= expectedPartners + 1 then
                if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                    print("[ValidateAndExecuteGroup] Incomplete "..groupType.." group for "..request.actor:getData('id')..": has "..#group..", needs ".. (expectedPartners + 1))
                end
                return false  -- Defer until all partners present
            end
        end
    end

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[ValidateAndExecuteGroup] Validating "..groupType.." group with "..#group.." actors")
    end

    -- Collect all planned actions for POI validation (flatten arrays)
    local actions = {}
    for _, req in ipairs(group) do
        if req.actions then
            for _, action in ipairs(req.actions) do
                table.insert(actions, action)
            end
        end
    end

    -- Call POICoordinator to validate and potentially displace
    if CURRENT_STORY.PoiCoordinator and #actions > 0 then
        local success, reason = CURRENT_STORY.PoiCoordinator:MakePOIsAvailable(actions)

        if not success then
            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[ValidateAndExecuteGroup] Deferring "..groupType.." group: "..reason)
            end
            return false
        end

        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[ValidateAndExecuteGroup] POIs available for "..groupType.." group")
        end
    end

    -- Execute group based on type
    if groupType == "starts_with" then
        for _, request in ipairs(group) do
            -- Skip if already processed (has pendingGraphAction set)
            if request.pendingGraphAction then
                -- Already at sync point, skip to ready check
            elseif request.actions then
                local actorId = request.actor:getData('id')
                local currentGraphActionName = request.actor:getData('currentGraphActionName')

                -- Process actions: enqueue non-graph, store graph action
                for _, action in ipairs(request.actions) do
                    if action.Name == currentGraphActionName then
                        -- Graph action - store for synchronized execution
                        request.pendingGraphAction = action
                        if DEBUG then
                            print(string.format("[DIAG][ValidateAndExecuteGroup] Actor %s: stored pendingGraphAction=%s for eventId=%s",
                                actorId, action.Name, request.eventId))
                        end
                        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                            print("[ValidateAndExecuteGroup] Actor " .. actorId .. " waiting at sync point: " .. action.Name)
                        end
                    else
                        -- Non-graph action - enqueue immediately
                        self:EnqueueActionLinear(action, request.actor, request.eventId)
                        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                            print("[ValidateAndExecuteGroup] Actor " .. actorId .. " enqueued: " .. action.Name)
                        end
                    end
                end
                request.actions = nil  -- Clear to prevent re-processing
            end
        end

        -- Check if ALL actors are ready (have pendingGraphAction + queue empty + not executing)
        local allReady = All(group, function(r)
            if not r.pendingGraphAction then return true end  -- No graph action to sync
            local actorId = r.actor:getData('id')
            local queue = CURRENT_STORY.actionsQueues[actorId]
            local queueEmpty = not queue or #queue == 0
            local notExecuting = not r.actor:getData('currentAction')
            return queueEmpty and notExecuting
        end)

        if allReady then
            -- All at sync point and ready! Execute all graph actions together
            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[ValidateAndExecuteGroup] All " .. #group .. " actors ready, executing graph actions together")
            end

            for _, request in ipairs(group) do
                if request.pendingGraphAction then
                    if DEBUG then
                        print(string.format("[DIAG][ValidateAndExecuteGroup] allReady! Actor %s: executing pendingGraphAction=%s",
                            request.actor:getData('id'), request.pendingGraphAction.Name))
                    end
                    -- Fix 19: Ensure kick-off happens even if Move cleared the flag earlier
                    request.actor:setData('isAwaitingConstraints', true)
                    self:EnqueueActionLinear(request.pendingGraphAction, request.actor, request.eventId)
                end
                request.performed = true
            end
            return true
        else
            -- Not all ready yet
            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                local readyCount = #Where(group, function(r)
                    if not r.pendingGraphAction then return true end
                    local actorId = r.actor:getData('id')
                    local queue = CURRENT_STORY.actionsQueues[actorId]
                    return (not queue or #queue == 0) and not r.actor:getData('currentAction')
                end)
                print("[ValidateAndExecuteGroup] starts_with group: " .. readyCount .. "/" .. #group .. " ready, waiting...")
            end
            return false
        end
    elseif groupType == "concurrent" then
        -- Execute with random delays (EnqueueActionLinear handles kick-off)
        local shuffled = Shuffle(group)
        for _, request in ipairs(shuffled) do
            if request.actions then
                local delay = math.random(0, request.max_delay or 0)
                for _, action in ipairs(request.actions) do
                    Timer(function()
                        self:EnqueueActionLinear(action, request.actor, request.eventId)
                    end, delay, 1)
                end
            end
        end
    end

    return true
end

function ActionsOrchestrator:ValidateSingularConstraints()
    for actorId, request in pairs(self.eventRequests) do
        local actor = request.actor
        local eventId = request.eventId
        local constraints = request.constraints

        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            local actionNames = "not planned yet"
            if request.actions and #request.actions > 0 then
                actionNames = table.concat(Select(request.actions, function(a) return a.Name end), ", ")
            end
            print("[ValidateSingularConstraints] actorId ".. actorId.." ".." eventId "..tostring(eventId).." - actions: "..actionNames)
        end

        for _, constraint in ipairs(constraints) do
            local constraintActor = constraint.actorId
            local constraintEventId = constraint.eventId
            local constraintData = constraint.constraint

            if constraintData.type == 'after' then
                -- after constraints are satisfied if the target event has been performed. The constraint event is the target event.
                constraint.satisfied = inList(constraintEventId, self.fulfilled)
            elseif constraintData.type == 'before' then
                -- before constraints are only added for source events, therefore, the constraint is satisfied if all the source events have been performed
                constraint.satisfied = inList(constraintEventId, self.fulfilled)
            end

            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[ValidateSingularConstraints] actorId ".. actorId.." - constraint "..constraintData.type.." with actorId "..constraintActor.." and eventId "..constraintEventId..' isValid '..tostring(constraint.satisfied))
            end
        end

        request.constraints = Where(constraints, function(constraint) return not constraint.satisfied end)
        if #request.constraints == 0 then
            request.isValid = true
        end
    end
end

function ActionsOrchestrator:ValidateConcurrentConstraints()
    local memo = {}
    for actorId, request in pairs(self.eventRequests) do
        local actor = request.actor
        local eventId = request.eventId
        local constraints = request.constraints

        if not request.isValid and not memo[actorId] then

            local concurrentConstraints = Where(constraints, function(constraint) return constraint.constraint.type == 'concurent' or constraint.constraint.type == 'starts_with' end)
            -- concurent constraints are satisfied if all concurrent or starts_with events linked with the current one have all constraints satisfied
            local unsatisfied = Where(constraints, function(constraint) return (constraint.constraint.type == 'after' or constraint.constraint.type == 'before') and not constraint.satisfied end)
            local isThisValid = #unsatisfied == 0

            if isThisValid and #concurrentConstraints > 0 then
                if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                    local actionNames = "not planned yet"
                    if request.actions and #request.actions > 0 then
                        actionNames = table.concat(Select(request.actions, function(a) return a.Name end), ", ")
                    end
                    print("[ValidateConcurrentConstraints] actorId ".. actorId.." ".." eventId "..tostring(eventId).." - actions: "..actionNames)
                end

                for _, constraint in ipairs(concurrentConstraints) do
                    local constraintActor = constraint.actorId
                    local constraintEventId = constraint.eventId
                    local constraintData = constraint.constraint

                    local linkedRequest = self.eventRequests[constraintActor]
                    if linkedRequest and linkedRequest.eventId == constraintEventId then
                        local othersNotSatisfied = Where(linkedRequest.constraints, function(constraint) return (constraint.constraint.type == 'after' or constraint.constraint.type == 'before') and not constraint.satisfied end)
                        isThisValid = #othersNotSatisfied == 0
                    end

                    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        print("[ValidateConcurrentConstraints] actorId ".. actorId.." - constraint "..constraintData.type.." with actorId "..constraintActor.." and eventId "..constraintEventId..' isValid '..tostring(isThisValid))
                    end

                    if not isThisValid then
                        break
                    end
                end

                if isThisValid then
                    request.isValid = true
                end

                memo[actorId] = true
                for _, constraint in ipairs(concurrentConstraints) do
                    if self.eventRequests[constraint.actorId] then
                        self.eventRequests[constraint.actorId].isValid = isThisValid
                    end
                    memo[constraint.actorId] = true
                end
            end
        end
    end
end

---DEPRECATED: Use ProcessEventRequests for event-based planning flow.
---Kept for backward compatibility with direct action enqueuing.
function ActionsOrchestrator:ProcessActionRequests()
    self:ValidateSingularConstraints()
    self:ValidateConcurrentConstraints()

    self:ExecuteStartsWithRequests()
    self:ExecuteConcurrentRequests()
    self:ExecuteSingularRequests()

    self.eventRequests = Where(self.eventRequests, function(request) return not request.performed end)

    -- Process all POI queues after action execution
    for locationId, queue in pairs(self.poiQueues) do
        if #queue > 0 then
            self:ProcessPOIQueue(locationId)
        end
    end
end

function ActionsOrchestrator:ExecuteSingularRequests()
    for actorId, request in pairs(self.eventRequests) do
        -- Only execute if: valid, planned, not performed, and has no starts_with/concurrent constraints
        if request.isValid and request.planned and not request.performed then
            local hasGroupConstraints = Any(request.constraints, function(c)
                return c.constraint.type == 'starts_with' or c.constraint.type == 'concurent'
            end)

            if not hasGroupConstraints then
                local actor = request.actor
                local actions = request.actions
                local eventId = request.eventId

                if actions and #actions > 0 then
                    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        local actionNames = Select(actions, function(a) return a.Name end)
                        print("[ExecuteSingularRequests] actorId " ..
                        actorId ..
                        " " .. " eventId " .. tostring(eventId) .. " - actions: " ..
                        table.concat(actionNames, ", "))
                    end
                    request.performed = true
                    -- Add all actions to queue (EnqueueActionLinear handles kick-off)
                    for _, action in ipairs(actions) do
                        self:EnqueueActionLinear(action, actor, eventId)
                    end
                end
            end
        end
    end
end

function ActionsOrchestrator:ExecuteConcurrentRequests()
    for actorId, request in pairs(self.eventRequests) do
        if request.isValid and request.planned and not request.performed then
            local actor = request.actor
            local action = request.action
            local eventId = request.eventId
            local constraints = request.constraints


            local concurrentConstraints = Where(constraints,
                function(constraint) return constraint.constraint.type == 'concurent' end)
            if #concurrentConstraints > 0 and action then
                if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                    print("[ExecuteConcurrentRequests] actorId " ..
                    actorId ..
                    " " .. " eventId " .. tostring(eventId) .. " - action " ..
                    action.Name .. ': ' .. action:GetDynamicString())
                end

                local otherConcurrentRequests = Shuffle(DropNull(Select(concurrentConstraints, function(c)
                    if self.eventRequests[c.actorId] and self.eventRequests[c.actorId].eventId == c.eventId then
                        self.max_delay = c.max_delay
                        return self.eventRequests[c.actorId]
                    else
                        return nil
                    end
                end)))
                local random_max_delay = request.max_delay or (FirstOrDefault(otherConcurrentRequests) and FirstOrDefault(otherConcurrentRequests).max_delay) or 0
                request.max_delay = random_max_delay
                local allConcurrentRequests = Shuffle(concat({ request }, otherConcurrentRequests))

                -- Pre-check: Can all actors in this concurrent group acquire their POIs?
                local canExecute, reason = self:CanConstraintGroupExecute(allConcurrentRequests)
                if canExecute then
                    -- All POIs available - execute entire group with random delays
                    for _, concurrentRequest in ipairs(allConcurrentRequests) do
                        local delay = math.random(0, concurrentRequest.max_delay or 0)

                        concurrentRequest.performed = true
                        Timer(function(concurrentRequest)
                            -- Pass eventId from the captured request
                            self:EnqueueActionLinear(concurrentRequest.action, concurrentRequest.actor, concurrentRequest.eventId)
                        end, delay, 1, concurrentRequest, self)
                    end
                else
                    -- POIs not available - defer execution
                    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        print("[ExecuteConcurrentRequests] Deferring concurrent group for actor "..actorId.." event "..tostring(eventId)..": "..reason)
                    end
                    -- Don't mark as performed - will retry in next cycle
                end
            end
        end
    end
end

--- Check if all actors in a constraint group can acquire their required POIs
--- Used for starts_with and concurrent constraints to ensure temporal correctness
--- @param actorRequests table Array of action requests in the constraint group
--- @return boolean, string True if all can execute, false with reason if blocked
function ActionsOrchestrator:CanConstraintGroupExecute(actorRequests)
    if not actorRequests or #actorRequests == 0 then
        return true, nil  -- No requests to check
    end

    if not CURRENT_STORY.PoiCoordinator then
        -- POICoordinator not initialized - allow execution (backward compatibility)
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print('[CanConstraintGroupExecute] WARNING: POICoordinator not initialized')
        end
        return true, nil
    end

    local poiReservations = {}

    -- Collect POI requirements for all actors in the group
    for _, request in ipairs(actorRequests) do
        local action = request.action
        local actor = request.actor

        -- Check if this action requires a different POI
        if action.NextLocation then
            local currentLocationId = actor:getData('locationId')
            local targetLocationId = action.NextLocation.LocationId

            -- Check if same location OR same interaction area (main and clone are same physical spot)
            local isSameArea = currentLocationId == targetLocationId
            if not isSameArea and currentLocationId and targetLocationId then
                local currentBase = currentLocationId:gsub("_clone$", "")
                local targetBase = targetLocationId:gsub("_clone$", "")
                isSameArea = currentBase == targetBase
            end

            if not isSameArea then
                -- Actor needs to move to acquire this POI
                table.insert(poiReservations, {
                    actor = actor,
                    poi = action.NextLocation
                })
            end
        end
    end

    -- If no POI changes needed, group can execute
    if #poiReservations == 0 then
        return true, nil
    end

    -- Try atomic POI reservation for entire group
    local success, reason = CURRENT_STORY.PoiCoordinator:ReservePOIsForGroup(poiReservations)

    if not success then
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print('[CanConstraintGroupExecute] Group cannot execute: '..reason)
        end
        return false, reason
    end

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print('[CanConstraintGroupExecute] Group can execute, reserved '..#poiReservations..' POIs')
    end

    return true, nil
end

function ActionsOrchestrator:ExecuteStartsWithRequests()
    for actorId, request in pairs(self.eventRequests) do
        if request.isValid and request.planned and not request.performed then
            local actor = request.actor
            local action = request.action
            local eventId = request.eventId
            local constraints = request.constraints


            local startsWithConstraints = Where(constraints, function(constraint) return constraint.constraint.type == 'starts_with' end)
            if #startsWithConstraints > 0 and action then
                local allStartsWithRequests = concat({request}, DropNull(Select(startsWithConstraints, function(c) if self.eventRequests[c.actorId] and self.eventRequests[c.actorId].eventId == c.eventId then return self.eventRequests[c.actorId] else return nil end end)))

                -- Validate all partners are present before execution
                if #allStartsWithRequests == #startsWithConstraints + 1 then
                    -- Complete group - proceed with execution
                    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        print("[ExecuteStartsWithRequests] actorId ".. actorId.." ".." eventId "..tostring(eventId).." - action "..action.Name..': '..action:GetDynamicString())
                    end

                    -- Pre-check: Can all actors in this starts_with group acquire their POIs?
                    local canExecute, reason = self:CanConstraintGroupExecute(allStartsWithRequests)
                    if canExecute then
                        -- All POIs available - execute entire group atomically
                        for _, startsWithRequest in ipairs(allStartsWithRequests) do
                            if not startsWithRequest.performed and startsWithRequest.action then
                                startsWithRequest.performed = true
                                self:EnqueueActionLinear(startsWithRequest.action, startsWithRequest.actor, startsWithRequest.eventId)
                            elseif DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                                print("[ExecuteStartsWithRequests] Skipping already-performed action for "..startsWithRequest.actor:getData('id').." event "..tostring(startsWithRequest.eventId))
                            end
                        end
                    else
                        -- POIs not available - defer execution
                        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                            print("[ExecuteStartsWithRequests] Deferring starts_with group for actor "..actorId.." event "..tostring(eventId)..": "..reason)
                        end
                        -- Don't mark as performed - will retry in next cycle
                    end
                else
                    -- Incomplete group - defer execution
                    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        print("[ExecuteStartsWithRequests] Deferring "..actorId.."/"..tostring(eventId)..": waiting for partners (have "..#allStartsWithRequests..", need ".. (#startsWithConstraints + 1)..")")
                    end
                    -- Don't mark as performed - will retry in next cycle
                end
            end
        end
    end
end

function ActionsOrchestrator:EnqueueActionLinear(action, actor, eventId)
    -- I need to check wether the actor is in a different context, if so, I have to trigger a context switch and wait for it before executing.
    action.Performer = actor

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[EnqueueActionLinear] actorId ".. actor:getData('id').." - action "..action.Name..': '..action:GetDynamicString().." eventId: "..tostring(eventId))
    end

    -- Add action to queue for sequential execution via GetNextValidAction
    local actorId = actor:getData('id')
    actor:setData('eventId', eventId)  -- Store eventId on actor for reference

    -- CONTAMINATION CHECK: Verify actor and eventId consistency
    print(string.format("[CONTAMINATION_CHECK][EnqueueActionLinear] actorId=%s action=%s eventId=%s",
        actorId, action.Name, tostring(eventId)))

    -- Re-enqueued actions (from kick-off) go to front to maintain execution order
    if action._isReenqueue then
        table.insert(CURRENT_STORY.actionsQueues[actorId], 1, action)  -- Insert at front
        action._isReenqueue = nil  -- Clear flag
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[EnqueueActionLinear] Re-enqueued action to FRONT of queue for actor "..actorId..", queue size: "..#CURRENT_STORY.actionsQueues[actorId])
        end
    else
        table.insert(CURRENT_STORY.actionsQueues[actorId], action)  -- Insert at back (normal)
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[EnqueueActionLinear] Added action to queue for actor "..actorId..", queue size: "..#CURRENT_STORY.actionsQueues[actorId])
        end
    end

    -- If actor was awaiting constraints, kick off execution loop
    if actor:getData('isAwaitingConstraints') then
        local firstAction = table.remove(CURRENT_STORY.actionsQueues[actorId], 1)
        firstAction._isReenqueue = true  -- Mark for front-of-queue insertion if re-enqueued
        self:EnqueueAction(firstAction, actor, eventId)
        actor:setData('isAwaitingConstraints', false)  -- Clear immediately to prevent multiple kick-offs in same batch

        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[EnqueueActionLinear] Kicking off action loop for idle actor "..actorId.." with: "..firstAction.Name)
        end
    end
end

function ActionsOrchestrator:TriggerActionExecution(actor, action, eventId)
    -- Clear awaiting constraints flag when action execution begins
    actor:setData('isAwaitingConstraints', false)

    -- Store eventId on actor (since action instances are shared)
    -- Skip for artificial actions (navigation-only moves)
    if eventId and not action.isArtificial then
        actor:setData('currentGraphEventId', eventId)
    end

    local shouldAwaitContextSwitch = CURRENT_STORY.CurrentFocusedEpisode and actor:getData('currentEpisode') ~= CURRENT_STORY.CurrentFocusedEpisode.name
    if shouldAwaitContextSwitch then
        actor:setData('isAwaitingContextSwitch', true)
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[EnqueueActionLinear] actorId ".. actor:getData('id').." - action "..action.Name..': '..action:GetDynamicString().." - awaiting context switch")
        end
        self.actionQueue[actor:getData('id')] = { action = action, eventId = eventId }
        -- Background actors should not request camera focus
        if not actor:getData("isbackgroundactor") then
            CURRENT_STORY.CameraHandler:requestFocus(actor:getData('id'))
        end
    else
        self:PublishActionStarted(actor, action, eventId)
        action:Apply()
    end
end

function ActionsOrchestrator:PublishActionStarted(actor, action, eventId)
    -- Publish graph event start if action matches the expected graph action for this actor
    -- Artificial actions (Move, Wait) will naturally not match the graph action name
    if eventId and self.EventBus and CURRENT_STORY:is_a(GraphStory) then
        -- Check if this action matches the expected graph action for this actor's current event
        local currentGraphActionName = actor:getData('currentGraphActionName')

        if currentGraphActionName and action.Name == currentGraphActionName then
            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[EnqueueActionLinear] Publishing graph_event_start for "..eventId.." (action "..action.Name.." matches currentGraphActionName "..currentGraphActionName..")")
            end

            self.EventBus:publish("graph_event_start", {
                eventId = eventId,
                actorId = actor:getData('id'),
                actionName = action.Name
            })

            -- Check if this is part of a starts_with interaction
            -- Find all events that share the same starts_with relationId
            -- EventBus handles deduplication automatically
            local temporal = CURRENT_STORY.temporal[eventId]
            if temporal and temporal.relations then
                for _, relationId in ipairs(temporal.relations) do
                    local relation = CURRENT_STORY.temporal[relationId]
                    if relation and relation.type == 'starts_with' then
                        -- Find ALL events with this relationId (many-to-many)
                        for otherEventId, otherTemporal in pairs(CURRENT_STORY.temporal) do
                            if type(otherTemporal) == 'table' and otherTemporal.relations and otherEventId ~= eventId then
                                -- Check if this other event has the same relationId
                                for _, otherRelationId in ipairs(otherTemporal.relations) do
                                    if otherRelationId == relationId then
                                        -- This event is part of the same starts_with group
                                        local otherEvent = CURRENT_STORY.graph[otherEventId]
                                        if otherEvent and otherEvent.Entities and otherEvent.Entities[1] then
                                            if DEBUG then
                                                print("[ActionsOrchestrator] Publishing graph_event_start for starts_with group event "..otherEventId.." (actor "..otherEvent.Entities[1]..")")
                                            end

                                            self.EventBus:publish("graph_event_start", {
                                                eventId = otherEventId,
                                                actorId = otherEvent.Entities[1],
                                                actionName = otherEvent.Action
                                            })
                                        end
                                        break
                                    end
                                end
                            end
                        end
                        break  -- Only handle first starts_with relation
                    end
                end
            end
        elseif DEBUG and DEBUG_ACTIONS_ORCHESTRATOR and currentGraphActionName then
            print("[EnqueueActionLinear] Skipping graph_event_start for "..eventId.." (action "..action.Name.." != currentGraphActionName "..currentGraphActionName..")")
        end
    end
end

function ActionsOrchestrator:TriggerActionFromQueue(actor)
    local actorId = actor:getData('id')
    local q = self.actionQueue[actorId]
    if q and q.action then
        local action = q.action
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[TriggerActionFromQueue] actorId ".. actorId.." - action "..action.Name..': '..action:GetDynamicString())
        end
        actor:setData('isAwaitingContextSwitch', false)
        self:PublishActionStarted(actor, action, q.eventId)
        action:Apply()
        self.actionQueue[actorId] = nil
        return true
    else
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[TriggerActionFromQueue] actorId ".. actorId.." - no action in queue")
        end
    end
    return false
end

--- Checks if an actor can be displaced from their current POI
-- @param actor The actor to check
-- @param visitedActors Optional table of already-checked actors for cycle detection
-- @return boolean True if actor can be displaced, false otherwise
function ActionsOrchestrator:CanActorBeDisplaced(actor, visitedActors)
    if not actor then return false end

    local actorId = actor:getData('id')

    -- Cycle detection: if we've already checked this actor, return false (cannot displace)
    visitedActors = visitedActors or {}
    if visitedActors[actorId] then
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[CanActorBeDisplaced] Cycle detected for actor '..actorId..', returning false')
        end
        return false
    end
    visitedActors[actorId] = true

    -- Check if actor is first in execution queue and POI is available
    local queuedLocationId = actor:getData('queuedForLocationId')
    if queuedLocationId and self.poiQueues[queuedLocationId] then
        local queue = self.poiQueues[queuedLocationId]

        if #queue > 0 and queue[1].actor == actor then
            -- Actor is first in queue - check if POI is acquirable
            local targetPOI = FirstOrDefault(CURRENT_STORY.CurrentEpisode.POI,
                function(poi) return poi.LocationId == queuedLocationId end)

            if not targetPOI and CURRENT_STORY.PoiCoordinator then
                targetPOI = CURRENT_STORY.PoiCoordinator:GetClonePOI(queuedLocationId)
            end

            if targetPOI then
                local occupyingActor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds,
                    function(ped) return ped:getData('locationId') == queuedLocationId end)

                -- If no one there, or we're there, or occupant can be displaced
                if not occupyingActor or occupyingActor == actor or self:CanActorBeDisplaced(occupyingActor, visitedActors) then
                    -- POI is available/acquirable - actor about to execute, don't displace
                    if DEBUG and DEBUG_POI_ORCHESTRATION then
                        print('[CanActorBeDisplaced] Actor '..actorId..' is first in queue and POI acquirable, cannot displace')
                    end
                    return false
                end
            end
        end
    end

    -- CAN displace if actor finished story
    if actor:getData('storyEnded') then
        return true
    end

    -- Get actor's current POI for subsequent checks
    local locationId = actor:getData('locationId')
    local currentPOI = nil
    if locationId then
        currentPOI = FirstOrDefault(CURRENT_STORY.CurrentEpisode.POI,
            function(poi) return poi.LocationId == locationId end)

        if not currentPOI and CURRENT_STORY.PoiCoordinator then
            currentPOI = CURRENT_STORY.PoiCoordinator:GetClonePOI(locationId)
        end
    end

    -- Cannot displace if waiting for interaction
    if actor:getData('isWaitingForInteraction') then
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[CanActorBeDisplaced] Actor '..actorId..' is waiting for interaction, cannot displace')
        end
        return false
    end

    -- Cannot displace if currently in interaction action
    local currentAction = actor:getData('currentAction')
    local isInInteractionAction = currentAction and Any(CURRENT_STORY.Interactions, function(a) return a:lower() == currentAction:lower() end)
    if isInInteractionAction then
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[CanActorBeDisplaced] Actor '..actorId..' is in interaction action '..currentAction..', cannot displace')
        end
        return false
    end

    -- Cannot displace if actor is in mid-chain with pending same-POI actions
    local actorChainId = actor:getData('mappedChainId')
    if actorChainId and locationId then
        -- Check if next event in chain requires the same POI
        if CURRENT_STORY.EventPlanner and CURRENT_STORY.EventPlanner.actorNextEvents then
            local nextEventId = CURRENT_STORY.EventPlanner.actorNextEvents[actorId]
            if nextEventId and CURRENT_STORY.poiMap and CURRENT_STORY.poiMap[nextEventId] then
                for _, mapping in ipairs(CURRENT_STORY.poiMap[nextEventId]) do
                    if mapping.chainId == actorChainId and mapping.value == locationId then
                        -- Actor has a pending event in the same chain at the same POI
                        if DEBUG and DEBUG_POI_ORCHESTRATION then
                            print('[CanActorBeDisplaced] Actor '..actorId..
                                  ' has pending chain action ('..nextEventId..
                                  ') at same POI '..locationId..', cannot displace')
                        end
                        return false
                    end
                end
            end
        end
    end

    -- Can displace if in interactionsOnly POI doing non-interaction action
    -- BUT NOT if actor is part of an active interaction (may have follow-up actions like Drink, Give)
    if currentPOI and currentPOI.interactionsOnly then
        -- Check if actor is part of an active interaction at this POI
        local isInActiveInteraction, primaryPoiId = false, nil
        if CURRENT_STORY.PoiCoordinator then
            isInActiveInteraction, primaryPoiId = CURRENT_STORY.PoiCoordinator:IsActorInInteraction(locationId, actorId)
        end

        if isInActiveInteraction then
            if DEBUG and DEBUG_POI_ORCHESTRATION then
                print('[CanActorBeDisplaced] Actor '..actorId..' is part of active interaction at '..(primaryPoiId or 'unknown')..', cannot displace')
            end
            return false  -- Stay at interaction POI for follow-up actions
        end

        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[CanActorBeDisplaced] Actor '..actorId..' is in interaction-only POI doing non-interaction action, CAN displace')
        end
        return true
    end

    -- Can displace if awaiting non-interaction constraints
    if actor:getData('isAwaitingConstraints') then
        return true
    end

    -- Default: cannot displace (actor is actively executing)
    return false
end

--- Displaces an actor from their current POI to a better position
-- Priority order:
-- 1. POIs with no PossibleActions (empty transit POIs), same region
-- 2. POIs not busy and not reserved, same region
-- 3. POIs with no PossibleActions, any region
-- 4. POIs not busy and not reserved, any region
-- 5. Fallback: any non-busy POI
-- @param actor The actor to displace
-- @param reason String describing why displacement is occurring
-- @return boolean True if displacement succeeded, false otherwise
function ActionsOrchestrator:DisplaceActor(actor, reason)
    local actorId = actor:getData('id')
    local currentLocationId = actor:getData('locationId')
    local currentPOI = FirstOrDefault(CURRENT_STORY.CurrentEpisode.POI,
        function(poi) return poi.LocationId == currentLocationId end)

    if not currentPOI and CURRENT_STORY.PoiCoordinator then
        currentPOI = CURRENT_STORY.PoiCoordinator:GetClonePOI(currentLocationId)
    end

    if not currentPOI then
        print('[DisplaceActor] WARNING: No current POI found for actor '..actorId)
        return false
    end

    -- Find all Move actions from current location
    local moveActions = Where(currentPOI.PossibleActions,
        function(a) return a.Name == 'Move' end)

    if #moveActions == 0 then
        print('[DisplaceActor] WARNING: No Move actions available from POI '..currentPOI.Description)
        return false
    end

    -- Get currently reserved POIs
    local reservedPOIs = {}
    for _, ped in ipairs(CURRENT_STORY.CurrentEpisode.peds) do
        local reservedId = ped:getData('reservedLocationId')
        if reservedId then
            reservedPOIs[reservedId] = true
        end
    end

    -- Priority 0: Check if actor has a planned target and it's reachable
    local targetMove = nil
    if CURRENT_STORY.EventPlanner and CURRENT_STORY.EventPlanner.plannedTargets then
        local plannedTarget = CURRENT_STORY.EventPlanner.plannedTargets[actorId]
        if plannedTarget and plannedTarget ~= currentLocationId then
            -- Find a Move action that leads to the planned target
            local plannedMoveAction = FirstOrDefault(moveActions, function(a)
                return a.NextLocation and a.NextLocation.LocationId == plannedTarget
                    and not a.NextLocation.isBusy
            end)

            if plannedMoveAction then
                targetMove = plannedMoveAction
                if DEBUG and DEBUG_POI_ORCHESTRATION then
                    print('[DisplaceActor] Using planned target '..plannedTarget..' for actor '..actorId)
                end
            elseif DEBUG and DEBUG_POI_ORCHESTRATION then
                print('[DisplaceActor] Planned target '..plannedTarget..' not reachable or busy, using fallback')
            end
        end
    end

    -- If no planned target or planned target not reachable, use priority-based selection
    if not targetMove then
        -- Priority 1: POIs with no actions (pure transit points), same region, not busy, not reserved
        local candidates = Where(moveActions, function(a)
            return #a.NextLocation.PossibleActions == 0
                and a.NextLocation.Region ~= nil and a.NextLocation.Region.name == currentPOI.Region.name
                and not a.NextLocation.isBusy
                and not reservedPOIs[a.NextLocation.LocationId]
        end)

        -- Priority 2: POIs not busy and not reserved, same region
        if #candidates == 0 then
            candidates = Where(moveActions, function(a)
                return not a.NextLocation.isBusy and not reservedPOIs[a.NextLocation.LocationId]
                    and a.NextLocation.Region ~= nil and a.NextLocation.Region.name == currentPOI.Region.name
            end)
        end

        -- Priority 3: POIs with no actions (pure transit points), any region
        if #candidates == 0 then
            candidates = Where(moveActions, function(a)
                return #a.NextLocation.PossibleActions == 0
                    and not a.NextLocation.isBusy
                    and not reservedPOIs[a.NextLocation.LocationId]
            end)
        end

        -- Priority 4: POIs not busy and not reserved, any region
        if #candidates == 0 then
            candidates = Where(moveActions, function(a)
                return not a.NextLocation.isBusy and not reservedPOIs[a.NextLocation.LocationId]
            end)
        end

        -- Fallback: any non-busy POI
        if #candidates == 0 then
            candidates = Where(moveActions, function(a)
                return not a.NextLocation.isBusy
            end)
        end

        if #candidates == 0 then
            print('[DisplaceActor] WARNING: No valid displacement target for actor '..actorId..' from '..currentPOI.Description)
            return false
        end

        -- Remove from POI queue if queued
        local queuedLocationId = actor:getData('queuedForLocationId')
        if queuedLocationId then
            self:RemoveFromQueue(actor, queuedLocationId)
        end

        targetMove = PickRandom(candidates)
        if not targetMove or not targetMove.NextLocation then
            print('[DisplaceActor] WARNING: Failed to select displacement target for actor '..actorId)
            return false
        end
    end -- End of "if not targetMove" block

    -- CRITICAL: Clear old POI's busy flag BEFORE setting new location as busy
    -- Otherwise old POI remains permanently marked busy with no occupying actor → deadlock
    currentPOI.isBusy = false
    if DEBUG and DEBUG_POI_ORCHESTRATION then
        print('[DisplaceActor] Cleared isBusy for old POI '..currentPOI.LocationId)
    end

    targetMove.NextLocation.isBusy = true
    actor:setData('locationId', targetMove.NextLocation.LocationId)

    -- CRITICAL: Also update EventPlanner's planning-time location tracking
    -- Otherwise NeedsMove will use stale location when planning next event
    if CURRENT_STORY and CURRENT_STORY.EventPlanner then
        CURRENT_STORY.EventPlanner.actorLocations[actorId] = targetMove.NextLocation.LocationId
        if DEBUG then
            print('[DisplaceActor] Updated EventPlanner.actorLocations for '..actorId..' to '..targetMove.NextLocation.LocationId)
        end
    end

    targetMove.Performer = actor
    targetMove:Apply() -- Vacate the current POI and move to the displacement POI

    -- Step 6: Mark actor's eventRequest for re-planning if displacement invalidated navigation
    local eventRequest = self.eventRequests[actorId]
    if eventRequest and eventRequest.planned and not eventRequest.performed then
        eventRequest.needsReplanning = true
        eventRequest.displacementReason = reason

        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[DisplaceActor] Flagged eventRequest for actor '..actorId..' event '..
                  (eventRequest.eventId or 'unknown')..' for re-planning after displacement')
        end
    end

    if DEBUG and DEBUG_POI_ORCHESTRATION then
        print('[DisplaceActor] '..reason..' - Moved actor '..actorId..
            ' from '..currentPOI.Description..' to '..targetMove.NextLocation.Description)
    end

    -- Step 5: If displaced to fallback (not planned target), enqueue recovery Move
    -- This ensures actor reaches their planned POI after displacement
    if CURRENT_STORY.EventPlanner and CURRENT_STORY.EventPlanner.plannedTargets then
        local plannedTarget = CURRENT_STORY.EventPlanner.plannedTargets[actorId]
        local actualTarget = targetMove.NextLocation.LocationId

        if plannedTarget and plannedTarget ~= actualTarget then
            -- Actor was displaced to fallback, needs recovery Move to planned target
            local plannedPOI = FirstOrDefault(CURRENT_STORY.CurrentEpisode.POI,
                function(poi) return poi.LocationId == plannedTarget end)

            if plannedPOI then
                -- Find Move action from fallback to planned target
                local recoveryMove = FirstOrDefault(targetMove.NextLocation.PossibleActions,
                    function(a) return a.Name == 'Move' and a.NextLocation and a.NextLocation.LocationId == plannedTarget end)

                if recoveryMove then
                    recoveryMove.Performer = actor
                    self:EnqueueActionLinear(recoveryMove, actor, nil)
                    if DEBUG then
                        print('[DisplaceActor] Enqueued recovery Move from '..actualTarget..' to planned target '..plannedTarget)
                    end
                elseif DEBUG then
                    print('[DisplaceActor] WARNING: No direct Move from '..actualTarget..' to planned target '..plannedTarget)
                end
            end
        end
    end

    return true
end

--- Adds an actor to the execution queue for a specific POI
-- @param actor The actor to enqueue
-- @param action The action to execute once POI is available
-- @param eventId The graph event ID
-- @param locationId The target POI location ID
function ActionsOrchestrator:EnqueueForPOI(actor, action, eventId, locationId)
    if not self.poiQueues[locationId] then
        self.poiQueues[locationId] = {}
    end

    local queue = self.poiQueues[locationId]

    -- Check if actor already in this queue
    if Any(queue, function(entry) return entry.actor == actor end) then
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[EnqueueForPOI] Actor '..actor:getData('id')..' already in queue for POI '..locationId)
        end
        return
    end

    -- Add to queue
    table.insert(queue, {
        actor = actor,
        action = action,
        eventId = eventId
    })

    -- CONTAMINATION CHECK: Verify POI queue entry consistency
    print(string.format("[CONTAMINATION_CHECK][EnqueueForPOI] actorId=%s action=%s action.eventId=%s param_eventId=%s locationId=%s",
        actor:getData('id'), action.Name, tostring(action.eventId), tostring(eventId), locationId))

    actor:setData('queuedForLocationId', locationId)

    if DEBUG and DEBUG_POI_ORCHESTRATION then
        print('[EnqueueForPOI] Actor '..actor:getData('id')..
              ' queued for POI '..locationId..' (position '..#queue..')')
    end

    -- If first in queue, try to acquire immediately
    if #queue == 1 then
        self:ProcessPOIQueue(locationId)
    end
end

--- Processes the execution queue for a specific POI
-- Checks if the first actor in queue can acquire the POI and execute
-- @param locationId The POI location ID to process
function ActionsOrchestrator:ProcessPOIQueue(locationId)
    local queue = self.poiQueues[locationId]
    if not queue or #queue == 0 then return end

    local first = queue[1]
    local actor = first.actor

    -- Find the target POI (check episode POIs first, then clone POIs)
    local targetPOI = FirstOrDefault(CURRENT_STORY.CurrentEpisode.POI,
        function(poi) return poi.LocationId == locationId end)

    -- If not found in episode POIs, check for clone POIs
    if not targetPOI and CURRENT_STORY.PoiCoordinator then
        targetPOI = CURRENT_STORY.PoiCoordinator:GetClonePOI(locationId)
        if targetPOI and DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[ProcessPOIQueue] Found clone POI: '..locationId)
        end
    end

    if not targetPOI then
        print('[ProcessPOIQueue] WARNING: POI '..locationId..' not found (neither in episode nor clone POIs)')
        return
    end

    -- Check if POI is available or can be acquired
    -- Check BOTH locationId (current) AND reservedLocationId (future) to prevent race conditions
    local occupyingActor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds,
        function(ped)
            return ped:getData('locationId') == locationId
                or ped:getData('reservedLocationId') == locationId
        end)

    if DEBUG and DEBUG_POI_ORCHESTRATION then
        print('[ProcessPOIQueue] Checking occupancy for POI '..locationId)
        print('  - occupyingActor: '..tostring(occupyingActor and occupyingActor:getData('id') or 'nil'))
        print('  - targetPOI.isBusy: '..tostring(targetPOI.isBusy))
        if occupyingActor then
            print('  - occupyingActor.locationId: '..tostring(occupyingActor:getData('locationId')))
            print('  - occupyingActor.reservedLocationId: '..tostring(occupyingActor:getData('reservedLocationId')))
        end
    end

    -- Handle stale POI reservation: POI is marked busy but no actor is there
    -- This occurs when actor reserved POI via GetNextValidAction (Location.lua line 882)
    -- but then got displaced to a different location before reaching the POI
    -- Clear the stale reservation so actor can acquire and corrective Move logic can run
    if not occupyingActor and targetPOI.isBusy then
        targetPOI.isBusy = false
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[ProcessPOIQueue] Cleared stale isBusy on POI '..locationId..
                  ' (no owner, actor '..actor:getData('id')..' first in queue)')
        end
        -- Fall through to acquisition check below
    end

    local canAcquire = false

    if not occupyingActor or occupyingActor == actor then
        canAcquire = true
    elseif self:CanActorBeDisplaced(occupyingActor) then
        -- Try to displace
        local displaced = self:DisplaceActor(occupyingActor,
            'Actor '..actor:getData('id')..' first in queue, needs POI')
        canAcquire = displaced
    else
        -- Check if both actors are targeting the same interaction
        -- If so, allow both (one will use clone offset)
        local actorNextEvent = first.eventId
        local occupantNextEvent = occupyingActor:getData('currentGraphEventId')

        if actorNextEvent and occupantNextEvent and CURRENT_STORY.graph then
            local actorEvent = CURRENT_STORY.graph[actorNextEvent]
            local occupantEvent = CURRENT_STORY.graph[occupantNextEvent]

            if actorEvent and occupantEvent and
               actorEvent.isInteraction and occupantEvent.isInteraction and
               actorEvent.interactionRelation and occupantEvent.interactionRelation and
               actorEvent.interactionRelation == occupantEvent.interactionRelation then
                -- Same interaction - allow both actors at same LocationId
                canAcquire = true
                if DEBUG and DEBUG_POI_ORCHESTRATION then
                    print('[ProcessPOIQueue] Allowing '..actor:getData('id')..' at same POI as '..occupyingActor:getData('id')..' - same interaction '..actorEvent.interactionRelation)
                end
            end
        end
    end

    if canAcquire then
        -- Success! Remove from queue
        table.remove(queue, 1)
        actor:setData('queuedForLocationId', nil)

        -- Clear pending POI flag - actor can now proceed with next action from queue
        actor:setData('pendingPOIAction', nil)

        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[ProcessPOIQueue] Actor '..actor:getData('id')..' acquired POI '..locationId)
        end

        -- Insert corrective Move if actor has been displaced in the meantime?
        local currentLocation = actor:getData('locationId')
        if currentLocation ~= locationId and first.action.Name ~= 'Move' then
            local currentPOI = FirstOrDefault(CURRENT_STORY.CurrentEpisode.POI,
                function(poi) return poi.LocationId == currentLocation end)

            if currentPOI then
                local moveAction = FirstOrDefault(currentPOI.allActions or currentPOI.PossibleActions,
                    function(a) return a.Name == 'Move' and a.NextLocation.LocationId == locationId end)

                if moveAction then
                    if DEBUG and DEBUG_POI_ORCHESTRATION then
                        print('[ProcessPOIQueue] Inserting corrective Move to '..targetPOI.Description)
                    end

                    -- CONTAMINATION CHECK: Verify action ownership before re-queueing
                    print(string.format("[CONTAMINATION_CHECK][ProcessPOIQueue_Insert] actorId=%s action=%s first.action.eventId=%s first.eventId=%s locationId=%s",
                        actor:getData('id'), first.action.Name, tostring(first.action.eventId), tostring(first.eventId), locationId))

                    -- Queue original action at FRONT to maintain execution order
                    table.insert(CURRENT_STORY.actionsQueues[actor:getData('id')], 1, first.action)

                    -- Apply move first (EventBus will publish when action executes from queue)
                    moveAction.Performer = actor
                    moveAction.isArtificial = true
                    moveAction:Apply()

                    -- Breaking the flow here; the original action will be retrieved by Location.GetNextValidAction after the Move completes and calls the OnGlobalActionFinished
                else
                    print('[ProcessPOIQueue] WARNING: No Move action found from '..currentPOI.Description..' to '..targetPOI.Description)
                end
            end
        else
            -- Actor already at correct location, execute immediately
            -- CONTAMINATION CHECK: Verify action ownership before direct execution
            print(string.format("[CONTAMINATION_CHECK][ProcessPOIQueue_Execute] actorId=%s action=%s first.action.eventId=%s first.eventId=%s locationId=%s",
                actor:getData('id'), first.action.Name, tostring(first.action.eventId), tostring(first.eventId), locationId))

            self:TriggerActionExecution(actor, first.action, first.eventId)
        end

        if #queue > 0 then
            -- Process next actor in queue
            self:ProcessPOIQueue(locationId)
        end
    else
        if DEBUG and DEBUG_POI_ORCHESTRATION then
            print('[ProcessPOIQueue] POI '..locationId..' still not available for actor '..actor:getData('id'))
        end
    end
end

--- Removes an actor from a POI queue (e.g., when displaced)
-- @param actor The actor to remove
-- @param locationId The POI location ID
function ActionsOrchestrator:RemoveFromQueue(actor, locationId)
    if not self.poiQueues[locationId] then return end

    local queue = self.poiQueues[locationId]
    for i, entry in ipairs(queue) do
        if entry.actor == actor then
            table.remove(queue, i)
            actor:setData('queuedForLocationId', nil)

            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print('[RemoveFromQueue] Removed actor '..actor:getData('id')..
                      ' from queue for POI '..locationId)
            end

            -- Process queue again (next actor becomes first)
            if #queue > 0 then
                self:ProcessPOIQueue(locationId)
            end
            break
        end
    end
end