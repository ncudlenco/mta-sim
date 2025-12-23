FIRST_ACTOR = nil
SECOND_ACTOR = nil
PERFORM_MULTI_ACTION = nil
PERFORM_MULTI_ACTION_FIRST_ACTOR = nil
MULTI_ACTION_DONE = nil

function OnGlobalActionFinished(delay, playerId, storyId, callback, destroyedItem)
    local function getActorData(player)
        return {
            id = player:getData('id'),
            Name = player:getData('first_name'),
            Surname = player:getData('surname'),
            Gender = player:getData('gender')
    }
    end

    Timer(function(playerId, storyId)
        if DEBUG then
            print("[DEBUG OnGlobalActionFinished] Timer fired for playerId: " .. playerId .. ", delay was: " .. delay)
            print("[DEBUG OnGlobalActionFinished] Callback is: " .. (callback and "PROVIDED" or "NIL"))
        end

        local story = CURRENT_STORY
        local lastAction = story.History[playerId][#story.History[playerId]]
        if DEBUG then
            outputConsole("GlobalAction:Apply - getting next valid action ".. playerId)
            print("GlobalAction:Apply - getting next valid action ".. playerId)
            if lastAction then
                print("[DEBUG OnGlobalActionFinished] Last action was: " .. lastAction.Name)
            else
                print("[DEBUG OnGlobalActionFinished] Last action is NIL")
            end
        end

        if callback then
            if DEBUG then
                print("[DEBUG OnGlobalActionFinished] Executing callback for " .. playerId)
            end
            local success, err = pcall(callback, playerId, storyId)
            if not success then
                print("[ERROR OnGlobalActionFinished] Callback error: " .. tostring(err))
            elseif DEBUG then
                print("[DEBUG OnGlobalActionFinished] Callback completed successfully")
            end
        elseif DEBUG then
            print("[DEBUG OnGlobalActionFinished] Skipping callback (nil)")
        end

        local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('id') == playerId end)
        if not actor then
            print("[FATAL ERROR] [ActionsGlobal] Actor "..playerId.." not found!")
            return
        end

        -- Complete action lifecycle: clear currentAction
        actor:setData('currentAction', nil)

        -- Publish graph event end (if this was a graph event and action matched)
        -- Save the completedEventId before clearing it, so we can pass it to NextActions
        local completedEventId = actor:getData('currentGraphEventId')
        local eventIdForNextAction = completedEventId  -- Preserve for NextAction propagation

        if completedEventId and story.EventBus and story:is_a(GraphStory) and lastAction then
            -- Check if the completed action matches the expected graph action for this actor
            local currentGraphActionName = actor:getData('currentGraphActionName')

            -- Only publish if the completed action was the actual graph event action
            -- Normalize graph action name to handle mappings (e.g., LookAtObject -> LookAt)
            local normalizedGraphActionName = story:NormalizeActionName(currentGraphActionName)
            if currentGraphActionName and lastAction.Name == normalizedGraphActionName then
                if DEBUG then
                    print("[ActionsGlobals] Publishing graph_event_end for "..completedEventId.." (action "..lastAction.Name.." matches currentGraphActionName "..currentGraphActionName..")")
                end

                story.EventBus:publish("graph_event_end", {
                    eventId = completedEventId,
                    actorId = playerId,
                    actionName = lastAction.Name
                })

                -- Clear both fields after successful publication (event has ended)
                actor:setData('currentGraphActionName', nil)
                actor:setData('currentGraphEventId', nil)

                -- Check if this is part of a synchronized interaction (starts_with or same_time)
                -- Find all events that share the same relationId
                -- EventBus handles deduplication automatically
                local temporal = story.temporal[completedEventId]
                if temporal and temporal.relations then
                    for _, relationId in ipairs(temporal.relations) do
                        local relation = story.temporal[relationId]
                        if relation and (relation.type == 'starts_with' or relation.type == 'same_time') then
                            -- Find ALL events with this relationId (many-to-many)
                            for otherEventId, otherTemporal in pairs(story.temporal) do
                                if type(otherTemporal) == 'table' and otherTemporal.relations and otherEventId ~= completedEventId then
                                    -- Check if this other event has the same relationId
                                    for _, otherRelationId in ipairs(otherTemporal.relations) do
                                        if otherRelationId == relationId then
                                            -- This event is part of the same synchronized group
                                            local otherEvent = story.graph[otherEventId]
                                            if otherEvent and otherEvent.Entities and otherEvent.Entities[1] then
                                                if DEBUG then
                                                    print("[ActionsGlobals] Publishing graph_event_end for "..relation.type.." group event "..otherEventId.." (actor "..otherEvent.Entities[1]..")")
                                                end

                                                story.EventBus:publish("graph_event_end", {
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
            elseif DEBUG and currentGraphActionName then
                print("[ActionsGlobals] Skipping graph_event_end for "..completedEventId.." (action "..lastAction.Name.." != normalizedGraphActionName "..normalizedGraphActionName..")")
            end

            -- For passive actors in starts_with interactions:
            -- Event may have been fulfilled by active actor, but action name doesn't match
            -- Check if event is in fulfilled list and clear eventId if so
            if completedEventId and not (currentGraphActionName and lastAction.Name == normalizedGraphActionName) then
                -- Main publication was skipped - check if event was fulfilled via starts_with
                if inList(completedEventId, story.ActionsOrchestrator.fulfilled) then
                    if DEBUG then
                        print("[ActionsGlobals] Clearing currentGraphEventId for "..playerId..
                              " - event "..completedEventId.." already fulfilled via starts_with")
                    end
                    actor:setData('currentGraphActionName', nil)
                    actor:setData('currentGraphEventId', nil)
                end
            end
        end

        if actor:getData('requestPause') then
            actor:setData('requestPause', false)
            actor:setData('paused', true)
            -- Background actors should not request camera focus
            if not actor:getData("isbackgroundactor") then
                CURRENT_STORY.CameraHandler:requestFocus(actor:getData('id'))
            end
            return
        end
        -- story.CameraHandler:freeFocus(playerId)

        local nextAction = nil

        if not lastAction then
            if DEBUG then
                outputConsole("GlobalAction:Apply - the last action was null, initiating the first action protocol")
                print("GlobalAction:Apply - the last action was null, initiating the first action protocol")
            end
            --The case where the first action didn't start because the location was busy
            local idx = actor:getData('startingPoiIdx')
            if DEBUG then
                print("Starting poi idx for ped "..idx)
            end
            if idx > 0 then
                local firstAction = CURRENT_STORY.CurrentEpisode.POI[idx]:GetNextValidAction(actor)
                if firstAction then
                    nextAction = firstAction
                else
                    -- Actor awaiting constraints - designed behavior, not an error
                    if DEBUG then
                        print("[ActionsGlobals] Actor "..actor:getData('id').." initial action not ready (awaiting constraints)")
                    end
                    return
                end
            end
        else
            if not LOAD_FROM_GRAPH and lastAction.NextAction then
                if isArray(lastAction.NextAction) then
                    nextAction = PickRandom(lastAction.NextAction)
                else
                    nextAction = lastAction.NextAction
                end
            elseif DEFINING_EPISODES then
                nextAction = EmptyAction({Performer = player})
            elseif lastAction.NextLocation then
                nextAction = lastAction.NextLocation:GetNextValidAction(lastAction.Performer)
                if not nextAction then
                    return
                end
            else
                print("[FATAL ERROR][ActionsGlobals] No valid action found for the ped "..actor:getData('id'))
            end
        end


        if nextAction then
            if not actor:getData('currentEpisode') then
                print('[ActionsGlobal] Actor does not have a current episode set! Trying to fix the actor '..actor:getData('id'))
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
                if closestPoi then
                    closestPoi.Region:OnPlayerHit(actor)
                end
            end

            if not actor:getData('currentEpisode') then
                print('[FatalError][ActionsGlobal] Actor cannot be assigned to an episode '..actor:getData('id'))
            end

            -- Use actor's currentGraphEventId instead of nextAction.eventId (actions don't store eventId)
            if DEBUG then
                local beforeRetrieve = actor:getData('currentGraphEventId')
                print(string.format("[OnGlobalActionFinished] BEFORE enqueue: actorId=%s currentGraphEventId=%s lastAction=%s",
                    actor:getData('id'), tostring(beforeRetrieve), tostring(lastAction and lastAction.Name or 'nil')))
            end

            local nextEventId = actor:getData('currentGraphEventId')

            -- CONTAMINATION CHECK: Verify eventId inheritance
            print(string.format("[CONTAMINATION_CHECK][OnGlobalActionFinished] actorId=%s nextAction=%s actor.currentGraphEventId=%s",
                actor:getData('id'), nextAction.Name, tostring(nextEventId)))

            story.ActionsOrchestrator:EnqueueAction(nextAction, actor, nextEventId)
        end

    end, delay, 1, playerId, storyId)
end