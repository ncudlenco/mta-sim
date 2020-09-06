Location = class(StoryLocationBase, function(o, x, y, z, angle, interior, description, region, compact, log)
    StoryLocationBase.init(o, description, {})
    o.X = x
    o.Y = y
    o.Z = z
    o.Angle = angle
    o.Interior = interior
    o.History = {}
    o.Region = region
    if not compact then
        o.position = Vector3(x,y,z)
        o.rotation = Vector3(0,0,angle)
    else
        o.position = {x=x, y=y, z=z}
        o.rotation = {x=0, y=0, z=angle}
    end
end)

function Location:SpawnPlayerHere(player)
    player:spawn(self.X, self.Y, self.Z, self.Angle, player.model, self.Interior)
    player:fadeCamera (true)
    local story = GetStory(player)
    if not STATIC_CAMERA then
        player:setCameraTarget (player)
    end
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
            local li = LastIndexOf(self.History, p)
            local lic = LastIndexOf(self.History, p.ClosingAction)
            if DEBUG then
                outputConsole("Evaluating validity of action "..x.Description)
                outputConsole("Has prerequisite "..p.Description)
                if p.ClosingAction then
                    outputConsole("With closing action "..p.ClosingAction.Description)
                else
                    outputConsole("Doesn't have a closing action")
                end
                outputConsole("Prerequisite last index: "..li)
                if p.ClosingAction then
                    outputConsole("Closing action last index "..lic)
                end
                if p.ClosingAction and lic > li or li ~= -1 then
                    outputConsole("Marked as valid")
                else
                    outputConsole("Not valid")
                end
            end
            return p.ClosingAction and lic > li or li ~= -1
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
    else
        if DEBUG then
            outputConsole("Next action chosen: "..next.Description)
        end
        if next.NextLocation == self then
            table.insert(self.History, next)
        else
            self.History = {}
            table.insert(next.NextLocation.History, next)
        end
    end
    return next
end