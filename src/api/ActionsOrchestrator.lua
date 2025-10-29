ActionsOrchestrator = class(function(o)
    o.actionRequests = {
        -- actorId: {eventId, actor, action, constraints = {{actorId, eventId, kind}, ...} }
    }
    o.fulfilled = {}
    o.actionQueue = {}
    o.lock = false
end)

function ActionsOrchestrator:Reset()
    self.actionRequests = {}
    self.actionQueue = {}
    self.fulfilled = {}
    self.lock = false
end

function ActionsOrchestrator:EnqueueAction(action, actor)
    CURRENT_STORY.CameraHandler:clearFocusRequests(actor:getData('id'))
    if CURRENT_STORY:is_a(GraphStory) then
        self:EnqueueActionGraph(action, actor)
    else
        self:EnqueueActionLinear(action, actor)
    end
end

function ActionsOrchestrator:EnqueueActionGraph(action, actor)
    -- every actor has to be mapped to the point in time as described in the graph of events where the action is supposed to be performed
    -- eg. of a temporal succession of events across actors
    --   |-----------------------next------------------------v
    -- a1.e1 -before-> a2.e1 -next-> a2.e2 -next-> a2.e3 -next-> a2.e4 -concurent-> a1.e2
    --   ^----after-----|                                          ^-----concurent----|
    -- algorithm below
    -- 1. map the currently requested action to the event in the graph of events (this is a given by the lastEvents table in the story object but additional actions might be inserted)
    -- 1. also note that an interaction is only triggered from one actor, even though both actors have an event each
    -- 2. retrieve the temporal constraints for the event
    -- 3. add them to the internal temporal constraints list
    -- 4. whenever an action is enqued, their previous event (if any) was fulfilled, check if the temporal constraints are met for any action requests
    -- 5. order the enqueued actions with constraints met, then apply them
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
    if #actorEvents > 1 then
        local previousEvent = actorEvents[#actorEvents - 1]
        table.insert(self.fulfilled, previousEvent.id)
    end

    if DEBUG then
        if not lastEvent then
            print("[EnqueueActionGraph] actorId ".. actor:getData('id').." - no last event for action "..action.Name..': '..action:GetDynamicString())
        else
            print("[EnqueueActionGraph] actorId ".. actor:getData('id').." event "..lastEvent.id.." - action "..action.Name..': '..action:GetDynamicString())
        end
    end

    local constraints = self:GetTemporalConstraints(actor, action, lastEvent)
    self.actionRequests[actor:getData('id')] = {eventId = lastEvent and lastEvent.id or nil, actor = actor, action = action, constraints = constraints}

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[EnqueueActionGraph] actorId ".. actor:getData('id').." - constraints "..stringifyTable(constraints))
        print("[EnqueueActionGraph] fulfilled "..stringifyTable(self.fulfilled))
    end

    self:ProcessActionRequests()
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
---@param lastEvent any The last event that was performed by the actor
---@return table constraints A list of temporal constraints in the form of {actorId, eventId, kind}, where kind is one of the following: "starts_with", "concurent", "after"
function ActionsOrchestrator:GetTemporalConstraints(actor, action, lastEvent)
    local constraints = {}
    local expectedAction = lastEvent and lastEvent.Action or nil
    local actorId = actor:getData('id')

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[GetTemporalConstraints] actorId ".. actorId.." - expected action "..expectedAction)
    end

    if expectedAction and (expectedAction == action.Name or action.Name:lower() == 'move') then
        local temporalData = CURRENT_STORY.temporal[lastEvent.id]

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
                        for _, linkedConstraint in ipairs(linkedConstraints) do
                            table.insert(constraints, {actorId = CURRENT_STORY.graph[linkedConstraint.key].Entities[1], eventId = linkedConstraint.key, constraint = constraint})

                            -- Find the event that is before the linked event, this is needed to enforce the order of the events for interactions, where only the initiator will have a request to execute the event
                            local eventBeforeLinkedStartsWith = FirstOrDefault(CURRENT_STORY.temporal, function(tempConstraint) return tempConstraint.next == linkedConstraint.key end)
                            if eventBeforeLinkedStartsWith then
                                table.insert(constraints, {actorId = CURRENT_STORY.graph[eventBeforeLinkedStartsWith.key].Entities[1], eventId = eventBeforeLinkedStartsWith.key, constraint = {type = 'after', source = temporalData.key, target = eventBeforeLinkedStartsWith.key}})
                            end
                        end
                    elseif constraint.type == 'concurent' or constraint.type == 'after' then
                        table.insert(constraints, {actorId = CURRENT_STORY.graph[constraint.target].Entities[1], eventId = constraint.target, constraint = constraint})
                    end
                end
            end

            --Find all the constraints of type before that have the current event as a target
            local beforeConstraints = Where(CURRENT_STORY.temporal, function(tempConstraint) return tempConstraint.type == 'before' and tempConstraint.target == lastEvent.id end)

            -- Find the events for which the current event has to wait (other actions that have a before constraint with the current event as a target)
            for _, beforeConstraint in ipairs(beforeConstraints) do
                table.insert(constraints, {actorId = CURRENT_STORY.graph[beforeConstraint.source].Entities[1], eventId = beforeConstraint.source, constraint = beforeConstraint})
            end
        end
    end
    return constraints
end

function ActionsOrchestrator:ValidateSingularConstraints()
    for actorId, request in pairs(self.actionRequests) do
        local actor = request.actor
        local action = request.action
        local eventId = request.eventId
        local constraints = request.constraints

        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[ValidateSingularConstraints] actorId ".. actorId.." ".." eventId "..tostring(eventId).." - action "..action.Name..': '..action:GetDynamicString())
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
    for actorId, request in pairs(self.actionRequests) do
        local actor = request.actor
        local action = request.action
        local eventId = request.eventId
        local constraints = request.constraints

        if not request.isValid and not memo[actorId] then

            local concurrentConstraints = Where(constraints, function(constraint) return constraint.constraint.type == 'concurent' or constraint.constraint.type == 'starts_with' end)
            -- concurent constraints are satisfied if all concurrent or starts_with events linked with the current one have all constraints satisfied
            local unsatisfied = Where(constraints, function(constraint) return (constraint.constraint.type == 'after' or constraint.constraint.type == 'before') and not constraint.satisfied end)
            local isThisValid = #unsatisfied == 0

            if isThisValid and #concurrentConstraints > 0 then
                if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                    print("[ValidateConcurrentConstraints] actorId ".. actorId.." ".." eventId "..tostring(eventId).." - action "..action.Name..': '..action:GetDynamicString())
                end

                for _, constraint in ipairs(concurrentConstraints) do
                    local constraintActor = constraint.actorId
                    local constraintEventId = constraint.eventId
                    local constraintData = constraint.constraint

                    local linkedRequest = self.actionRequests[constraintActor]
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
                    if self.actionRequests[constraint.actorId] then
                        self.actionRequests[constraint.actorId].isValid = isThisValid
                    end
                    memo[constraint.actorId] = true
                end
            end
        end
    end
end

--- Iterates through all the actions and applies them if the temporal constraints are met
--- there are multiple cases to consider:
--- 1. starts_with = the action is supposed to start at the same time as other actions
---      for interactions only one actor will reach this point, because the interaction is initiated by one actor,
---      CHECK how the last event is determined in this case
--- 2. after = the action is supposed to start (with a delay if specified) after other action
--- 3. before = the action is supposed to start before other actions, this is a reverse of constraint 2. and will be treated as such (the other action has to wait for this action to finish before it can start)
--- 4. concurent = the action is supposed to start concurrently with other actions: random order, random delay within 0 and max_delay
--- 5. watch out for deadlocks
function ActionsOrchestrator:ProcessActionRequests()

    -- This method is not implemented well. Some of the action requests are fulfilled at this step, if that happens, some other action requests might be unlocked.
    -- Here I have to understand when one request is ready to be executed and position it on the timeline with respect to the other requests.
    -- When one request is ready to be executed, I have to recheck all the other requests to see if they are ready to be executed as well.
    -- I have to be careful here to identify all the action requests that have to be performed at the same time
    -- Also, check what happens with the CameraHandler, context switch, actions being paused, etc. There is an interference between the ActionsOrchestrator and the CameraHandler
    self:ValidateSingularConstraints()
    self:ValidateConcurrentConstraints()

    --Now I need to execute all actions for the requests.
    --All groups of requests that have constraints of type starts_with should be executed together first
    --Then, all groups of requests that have constraints of type concurrent should be executed together, in random order, respecting the maximum delay
    --Then, all the other valid requests should be executed in the order they were added
    self:ExecuteStartsWithRequests()
    self:ExecuteConcurrentRequests()
    self:ExecuteSingularRequests()

    self.actionRequests = Where(self.actionRequests, function(request) return not request.performed end)
end

function ActionsOrchestrator:ExecuteSingularRequests()
    for actorId, request in pairs(self.actionRequests) do
        if request.isValid and not request.performed then
            local actor = request.actor
            local action = request.action
            local eventId = request.eventId
            local constraints = request.constraints

            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[ExecuteSingularRequests] actorId " ..
                actorId ..
                " " .. " eventId " .. tostring(eventId) .. " - action " ..
                action.Name .. ': ' .. action:GetDynamicString())
            end
            request.performed = true
            self:EnqueueActionLinear(action, actor, eventId)  -- Pass eventId
        end
    end
end

function ActionsOrchestrator:ExecuteConcurrentRequests()
    for actorId, request in pairs(self.actionRequests) do
        if request.isValid and not request.performed then
            local actor = request.actor
            local action = request.action
            local eventId = request.eventId
            local constraints = request.constraints


            local concurrentConstraints = Where(constraints,
                function(constraint) return constraint.constraint.type == 'concurent' end)
            if #concurrentConstraints > 0 then
                if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                    print("[ExecuteConcurrentRequests] actorId " ..
                    actorId ..
                    " " .. " eventId " .. tostring(eventId) .. " - action " ..
                    action.Name .. ': ' .. action:GetDynamicString())
                end

                local otherConcurrentRequests = Shuffle(DropNull(Select(concurrentConstraints, function(c)
                    if self.actionRequests[c.actorId] and self.actionRequests[c.actorId].eventId == c.eventId then
                        self.max_delay = c.max_delay
                        return self.actionRequests[c.actorId]
                    else
                        return nil
                    end
                end)))
                local random_max_delay = request.max_delay or FirstOrDefault(otherConcurrentRequests).max_delay or 0
                request.max_delay = random_max_delay
                local allConcurrentRequests = Shuffle(concat({ request }, otherConcurrentRequests))

                for _, concurrentRequest in ipairs(allConcurrentRequests) do
                    local delay = math.random(0, concurrentRequest.max_delay or 0)

                    concurrentRequest.performed = true
                    Timer(function(concurrentRequest)
                        -- Pass eventId from the captured request
                        self:EnqueueActionLinear(concurrentRequest.action, concurrentRequest.actor, concurrentRequest.eventId)
                    end, delay, 1, concurrentRequest, self)
                end
            end
        end
    end
end
function ActionsOrchestrator:ExecuteStartsWithRequests()
    for actorId, request in pairs(self.actionRequests) do
        if request.isValid and not request.performed then
            local actor = request.actor
            local action = request.action
            local eventId = request.eventId
            local constraints = request.constraints


            local startsWithConstraints = Where(constraints, function(constraint) return constraint.constraint.type == 'starts_with' end)
            if #startsWithConstraints > 0 then
                local allStartsWithRequests = concat({request}, DropNull(Select(startsWithConstraints, function(c) if self.actionRequests[c.actorId] and self.actionRequests[c.actorId].eventId == c.eventId then return self.actionRequests[c.actorId] else return nil end end)))

                if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                    print("[ExecuteStartsWithRequests] actorId ".. actorId.." ".." eventId "..tostring(eventId).." - action "..action.Name..': '..action:GetDynamicString())
                end
                for _, startsWithRequest in ipairs(allStartsWithRequests) do
                    if not startsWithRequest.performed then
                        startsWithRequest.performed = true
                        self:EnqueueActionLinear(startsWithRequest.action, startsWithRequest.actor, startsWithRequest.eventId)  -- Pass eventId
                    elseif DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                        print("[ExecuteStartsWithRequests] Skipping already-performed action for "..startsWithRequest.actor:getData('id').." event "..tostring(startsWithRequest.eventId))
                    end
                end
            end
        end
    end
end

function ActionsOrchestrator:EnqueueActionLinear(action, actor, eventId)
    -- I need to check wether the actor is in a different context, if so, I have to trigger a context switch and wait for it before executing.
    action.Performer = actor
    actor:setData('isAwaitingConstraints', false)

    if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
        print("[EnqueueActionLinear] actorId ".. actor:getData('id').." - action "..action.Name..': '..action:GetDynamicString().." eventId: "..tostring(eventId))
    end

    -- Store eventId on actor (since action instances are shared)
    -- This is stored regardless of whether we publish, for event_end
    if eventId then
        actor:setData('currentGraphEventId', eventId)
    end

    -- Publish graph event start ONLY if action matches the event's expected action
    -- This filters out artificially inserted Move actions
    if eventId and CURRENT_STORY.EventBus and CURRENT_STORY:is_a(GraphStory) then
        local expectedAction = CURRENT_STORY.graph[eventId] and CURRENT_STORY.graph[eventId].Action

        -- Only publish if this action is the actual graph event action
        if expectedAction and action.Name == expectedAction then
            if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
                print("[EnqueueActionLinear] Publishing graph_event_start for "..eventId.." (action matches)")
            end

            CURRENT_STORY.EventBus:publish("graph_event_start", {
                eventId = eventId,
                actorId = actor:getData('id'),
                actionName = action.Name
            })
        elseif DEBUG and DEBUG_ACTIONS_ORCHESTRATOR and expectedAction then
            print("[EnqueueActionLinear] Skipping graph_event_start for "..eventId.." (action "..action.Name.." != expected "..expectedAction..")")
        end
    end

    local shouldAwaitContextSwitch = CURRENT_STORY.CurrentFocusedEpisode and actor:getData('currentEpisode') ~= CURRENT_STORY.CurrentFocusedEpisode.name
    if shouldAwaitContextSwitch then
        actor:setData('isAwaitingContextSwitch', true)
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[EnqueueActionLinear] actorId ".. actor:getData('id').." - action "..action.Name..': '..action:GetDynamicString().." - awaiting context switch")
        end
        self.actionQueue[actor:getData('id')] = action
        CURRENT_STORY.CameraHandler:requestFocus(actor:getData('id'))
    else
        action:Apply()
    end
end

function ActionsOrchestrator:TriggerActionFromQueue(actor)
    local actorId = actor:getData('id')
    local action = self.actionQueue[actorId]
    if action then
        if DEBUG and DEBUG_ACTIONS_ORCHESTRATOR then
            print("[TriggerActionFromQueue] actorId ".. actorId.." - action "..action.Name..': '..action:GetDynamicString())
        end
        actor:setData('isAwaitingContextSwitch', false)
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