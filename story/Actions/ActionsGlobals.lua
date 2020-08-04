function OnGlobalActionFinished(delay, playerId, storyId, callback, destroyedItem)
    Timer(function(playerId, storyId)
        local story = STORIES[playerId][storyId]
        local lastAction = story.History[#story.History]
        if DEBUG then
            outputConsole("GlobalAction:Apply - getting next valid action")
        end
        if callback then
            callback(playerId, storyId)
        end
        if lastAction.NextAction then
            if isArray(lastAction.NextAction) then
                PickRandom(lastAction.NextAction):Apply()
            else
                lastAction.NextAction:Apply()
            end
        elseif lastAction.NextLocation then
            lastAction.NextLocation:GetNextValidAction(lastAction.Performer):Apply()
        end
    end, delay, 1, playerId, storyId)    
end