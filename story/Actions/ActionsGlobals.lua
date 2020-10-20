function OnGlobalActionFinished(delay, playerId, storyId, callback, destroyedItem)
    Timer(function(playerId, storyId)
        local story = CURRENT_STORY
        local lastAction = story.History[playerId][#story.History[playerId]]
        if DEBUG then
            outputConsole("GlobalAction:Apply - getting next valid action")
        end
        if callback then
            callback(playerId, storyId)
        end

        local nextAction = nil
        if lastAction.NextAction then
            if isArray(lastAction.NextAction) then
                nextAction = PickRandom(lastAction.NextAction)
            else
                nextAction = lastAction.NextAction
            end
        elseif lastAction.NextLocation then
            nextAction = lastAction.NextLocation:GetNextValidAction(lastAction.Performer)
        end
        nextAction.Performer = lastAction.Performer
        nextAction:Apply()

    end, delay, 1, playerId, storyId)    
end