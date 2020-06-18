function OnGlobalActionFinished(delay, playerId, storyId, callback)
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
            lastAction.NextAction:Apply()
        else
            lastAction.NextLocation:GetNextValidAction(lastAction.Performer):Apply()
        end
    end, delay, 1, playerId, storyId)    
end