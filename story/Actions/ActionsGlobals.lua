function OnGlobalActionFinished(delay, playerId, storyId, callback, destroyedItem)
    --TODO: log events here, update the time taken inside the timer
    local actionStartTime = CURRENT_STORY.Logger:GetElapsedTime()
    Timer(function(playerId, storyId)
        local story = CURRENT_STORY
        local lastAction = story.History[playerId][#story.History[playerId]]
        if lastAction then
            --TODO: log events here
            local event = {
                Actor = { 
                    id = lastAction.Performer:getData('id'), 
                    relativePosition = lastAction.Performer:getData('relativePosition') 
                },
                Action = lastAction.Description,
                Location = lastAction.Performer:getData('currentRegion'),
                Start = actionStartTime,
                End = CURRENT_STORY.Logger:GetElapsedTime(),
                Target = {
                    id = lastAction.TargetItem.ObjectId or lastAction.TargetItem.LocationId or lastAction.TargetItem:getData('id'),
                    type = lastAction.TargetItem.StoryItemType,
                    relativePosition = lastAction.TargetItem:getData('relativePosition')
                }
            }
            table.insert(GRAPH.Events, event)
        end
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