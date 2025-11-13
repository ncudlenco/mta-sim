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

        -- Publish graph event end (if this was a graph event and action matched)
        -- Save the completedEventId before clearing it, so we can pass it to NextActions
        local completedEventId = actor:getData('currentGraphEventId')
        local eventIdForNextAction = completedEventId  -- Preserve for NextAction propagation

        if completedEventId and story.EventBus and story:is_a(GraphStory) and lastAction then
            local expectedAction = story.graph[completedEventId] and story.graph[completedEventId].Action

            -- Normalize graph action name to match simulator action names (e.g., INV-Give → Receive)
            local normalizedAction = expectedAction and story:NormalizeActionName(expectedAction) or nil

            -- Only publish if the completed action was the actual graph event action
            if normalizedAction and lastAction.Name == normalizedAction then
                if DEBUG then
                    print("[ActionsGlobals] Publishing graph_event_end for "..completedEventId.." (action "..lastAction.Name.." matches normalized "..normalizedAction..")")
                end

                story.EventBus:publish("graph_event_end", {
                    eventId = completedEventId,
                    actorId = playerId,
                    actionName = lastAction.Name
                })
            elseif DEBUG and expectedAction then
                print("[ActionsGlobals] Skipping graph_event_end for "..completedEventId.." (action "..lastAction.Name.." != normalized expected "..normalizedAction..")")
            end

            -- Clear the event ID after checking (always clear, even if we didn't publish)
            actor:setData('currentGraphEventId', nil)
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
        local isNextActionFromChain = false  -- Track if nextAction is from NextAction chain

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
                    if DEBUG then
                        print("[FATAL ERROR][ActionsGlobals] No valid initial action found for the ped "..actor:getData('id'))
                    end
                end
            end
        else
            if not LOAD_FROM_GRAPH and lastAction.NextAction then
                if isArray(lastAction.NextAction) then
                    nextAction = PickRandom(lastAction.NextAction)
                else
                    nextAction = lastAction.NextAction
                end
                isNextActionFromChain = true  -- This action is part of the same event chain
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

            -- Pass eventId when enqueueing NextAction from a chain (preserves eventId for NextAction inheritance)
            -- Otherwise, let the system look up eventId from lastEvents
            if isNextActionFromChain and eventIdForNextAction then
                if DEBUG then
                    print("[ActionsGlobals] Enqueueing NextAction with preserved eventId: "..eventIdForNextAction)
                end
                story.ActionsOrchestrator:EnqueueAction(nextAction, actor, eventIdForNextAction)
            else
                story.ActionsOrchestrator:EnqueueAction(nextAction, actor)
            end
            -- Insert here an action manager that keeps an eye on the temporal part from the graph.
            -- Initially, all the actors were spawned in their initial location, then the first action was applied, disregarding any temporal constraints.
            -- Now, the temporal constraints should be taken into account, the action should be applied only when the time is right.
            -- As a start, we will enforce next constraints, across actors
            -- nextAction.Performer = actor
            -- nextAction:Apply()
        end

    end, delay, 1, playerId, storyId)
end