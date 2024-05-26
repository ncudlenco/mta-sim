FIRST_ACTOR = nil
SECOND_ACTOR = nil
PERFORM_MULTI_ACTION = nil
PERFORM_MULTI_ACTION_FIRST_ACTOR = nil
MULTI_ACTION_DONE = nil

function OnGlobalActionFinished(delay, playerId, storyId, callback, destroyedItem)
    function getActorData(player)
        return {
            id = player:getData('id'),
            Name = player:getData('first_name'),
            Surname = player:getData('surname'),
            Gender = player:getData('gender')
    }
    end

    Timer(function(playerId, storyId)
        local story = CURRENT_STORY
        local lastAction = story.History[playerId][#story.History[playerId]]
        if DEBUG then
            outputConsole("GlobalAction:Apply - getting next valid action")
            print("GlobalAction:Apply - getting next valid action")
        end
        if callback then
            callback(playerId, storyId)
        end

        local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped) return ped:getData('id') == playerId end)
        if not actor then
            print("[FATAL ERROR] [ActionsGlobal] Actor "..playerId.." not found!")
            return
        end
        if actor:getData('requestPause') then
            actor:setData('requestPause', false)
            actor:setData('paused', true)
            CURRENT_STORY.CameraHandler:requestFocus(actor:getData('id'))
            return
        end
        -- story.CameraHandler:freeFocus(playerId)

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
                    firstAction:Apply()
                else
                    if DEBUG then
                        print("No valid action found, the ped is waiting "..actor:getData('id'))
                    end
                end
            end
            return
        end
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
        end

        nextAction.Performer = lastAction.Performer
        nextAction:Apply()

    end, delay, 1, playerId, storyId)
end