Location = class(StoryLocationBase, function(o, x, y, z, angle, interior, description)
    StoryLocationBase.init(o, description, {})
    o.X = x
    o.Y = y
    o.Z = z
    o.Angle = angle
    o.Interior = interior
    o.position = Vector3(x,y,z)
    o.rotation = Vector3(0,0,angle)
end)

function Location:SpawnPlayerHere(player)
    player:spawn(self.X, self.Y, self.Z, self.Angle, player.model, self.Interior)
    player:fadeCamera (true)
    player:setCameraTarget (player)
    -- player:setPosition(self.X, self.Y, self.Z, warp)
    -- player:setRotation(0,0,self.Angle,"default",true)
    if DEBUG then
        outputConsole("Location:SpawnPlayerHere")
    end
end

function Location:GetNextValidAction(player)
    if DEBUG then
        outputConsole("Location:GetNextValidAction")
    end
    if player == nil and DEBUG then
        outputConsole("Error Location:GetNextValidAction: Actor is null ")
    end
    local story = GetStory(player)
    if DEBUG and story == nil then
        outputConsole("Error Location:GetNextValidAction: story is null")
    end
    if #story.History >= story.MaxActions then
        if DEBUG then
            outputConsole("Location:GetNextValidAction - max story actions reached. Ending the current story")
        end
        return EndStory(player)
    end
    local previousAction = nil
    if #story.History >= 1 then
        previousAction = story.History[#story.History]
    end

    local nextValidActions = Where(self.PossibleActions, function(x)
        return x ~= previousAction and All(x.Prerequisites, function(p)
            return LastIndexOf(story.History, p) > LastIndexOf(story.History, p.ClosingAction)
        end)
    end)
    if next(nextValidActions) == nil then
        if DEBUG then
            outputConsole("Location:GetNextValidAction - No more valid story actions found. Ending the current story")
        end
        return EndStory(player)
    end
    local next = PickRandom(nextValidActions);
    if not next then
        if DEBUG then
            outputConsole("Location:GetNextValidAction - next action was null. Ending the current story")
        end
        return EndStory(player)
    end
    return next
end