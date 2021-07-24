Location = class(StoryLocationBase, function(o, x, y, z, angle, interior, description, region, compact, log)
    StoryLocationBase.init(o, description, {})
    o.X = x
    o.Y = y
    o.Z = z
    o.Angle = angle
    o.Interior = interior
    o.History = {}
    o.Region = region
    o.isBusy = false
    if not compact then
        o.position = Vector3(x,y,z)
        o.rotation = Vector3(0,0,angle)
    else
        o.position = {x=x, y=y, z=z}
        o.rotation = {x=0, y=0, z=angle}
    end
    o.allActions = {}
    o.metatable = {}
    --TODO: log atomic action here (location exists)
    --local event = {id = o.LocationId, Name = o.Description}
    --GRAPH.AtomicEvents[event.id] = event
end)

function Location:getData(key)
    return self.metatable[key]
end

function Location:setData(key, value)
    self.metatable[key] = value
end

function Location:SpawnPlayerHere(player)
    self.isBusy = true
    player:setData('locationId', self.LocationId)
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

function Location:Serialize(episode, relativePosition, _objects, _locations, _mainPOI, _saveMainPoiRelative)
    local objects = {}
    if _objects then
        objects = _objects
    end
    local locations = {}
    if _locations then
        locations = _locations
    end
    local serializedAllActions = {}
    for _, a in ipairs(self.allActions) do
        if DEBUG then
            print("Serialize:action "..a.id)
        end
        local serializedNextAction = nil
        if a.NextAction then
            if isArray(a.NextAction) then
                for _, na in ipairs(a.NextAction) do
                    table.insert(serializedNextAction, {id = na.id})
                end
            else
                serializedNextAction = { id = a.NextAction.id }
            end
        end
        local targetItemType = 'Object'
        local targetItemId = LastIndexOf(episode.Objects, a.TargetItem)
        if targetItemId < 0 then
            targetItemType = 'Location'
            targetItemId = LastIndexOf(episode.POI, a.TargetItem)
            if targetItemId < 0 then
                targetItemType = 'none'
            end
        end
        local closingAction = nil
        if a.ClosingAction then
            closingAction = {id = a.ClosingAction.id}
        end
        local serializedAction = {
            dynamicString = a:GetDynamicString(),
            id = a.id,
            nextAction = serializedNextAction,
            targetItem = {id = targetItemId, type = targetItemType},
            nextLocation = {id = LastIndexOf(episode.POI, a.NextLocation)},
            closingAction = closingAction,
            isClosingAction = a.IsClosingAction
        }

        if DEBUG then
            print("Serialize:serialized action "..serializedAction.dynamicString)
        end

        table.insert(serializedAllActions, serializedAction)
        local function processLocationDependency(location)
            if not location then
                return
            end
            if DEBUG then
                print("Serialize:process location relative "..location.id)
            end
            local locationCopy = {id = location.id or LastIndexOf(episode.POI, location)}
            --If next location is not myself and next location is not already processed in recursivity
            if 
                locationCopy.id ~= LastIndexOf(episode.POI, self)
                and #Where(locations, function (x) return x.id == locationCopy.id end) == 0
                and (not _mainPOI or locationCopy.id ~= LastIndexOf(episode.POI, _mainPOI) )
            then
                local targetItemRelativePosition = Vector3(location.position.x, location.position.y, location.position.z) - relativePosition

                locationCopy = location:Serialize(episode, relativePosition, objects, locations, _mainPOI or self, true)
                -- locationCopy.X = targetItemRelativePosition.x
                -- locationCopy.Y = targetItemRelativePosition.y
                -- locationCopy.Z = targetItemRelativePosition.z
                --This is probably handled in recursivity already
                -- for _,v in ipairs(dependentObjects) do
                --     if #Where(objects, function (x) return x.id == v.id end) == 0 then
                --         table.insert(objects, v)
                --     end
                -- end
                -- for _,v in ipairs(dependentLocations) do 
                --     if #Where(locations, function (x) return x.id == v.id end) == 0 then
                --         table.insert(locations, v)
                --     end
                -- end
                if #Where(locations, function (x) return x.id == locationCopy.id end) == 0 then
                    table.insert(locations, locationCopy)
                end
            end
        end
        if a.TargetItem and a.TargetItem.position and relativePosition then
            if targetItemType == 'Object' then
                if DEBUG then
                    outputConsole("Serialize:target object "..targetItemId)
                end

                local objectCopy = SampStoryObjectBase(a.TargetItem)
                local targetItemRelativePosition = Vector3(a.TargetItem.position.x, a.TargetItem.position.y, a.TargetItem.position.z) - relativePosition
                objectCopy.position = targetItemRelativePosition
                objectCopy.instance = nil
                objectCopy:UpdateData(true)
                objectCopy.id = targetItemId
                if #Where(objects, function (x) return x.id == objectCopy.id end) == 0 then
                    table.insert(objects, {
                        id = objectCopy.id, 
                        dynamicString = objectCopy.dynamicString
                    })
                end
            elseif targetItemType == 'Location' then
                if DEBUG then
                    print("Serialize:target location "..targetItemId)
                end
                processLocationDependency(a.TargetItem)
            end
        end
        if relativePosition then
            if DEBUG then
                print("Serialize:process location relative")
            end
            processLocationDependency(a.NextLocation)
        end
    end

    local serializedPossibleActions = {}
    for _, a in ipairs(self.PossibleActions) do
        table.insert(serializedPossibleActions, {id = a.id})
    end

    local serializedMainPoi = {
        X = self.X,
        Y = self.Y,
        Z = self.Z,
        Angle = self.Angle,
        Interior = self.Interior,
        Description = self.Description,
        allActions = serializedAllActions,
        PossibleActions = serializedPossibleActions,
        id = LastIndexOf(episode.POI, self)
    }
    if _saveMainPoiRelative then
        local targetItemRelativePosition = Vector3(self.X, self.Y, self.Z) - relativePosition
        serializedMainPoi.X = targetItemRelativePosition.x
        serializedMainPoi.Y = targetItemRelativePosition.y
        serializedMainPoi.Z = targetItemRelativePosition.z
    end
    return serializedMainPoi, objects, locations
end

function Location:GetNextRandomValidAction(player)
    local story = GetStory(player)

    local previousAction = nil
    if #story.History[player:getData('id')] >= 1 then
        previousAction = story.History[player:getData('id')][#story.History]
    end

    local nextValidActions = Where(self.PossibleActions, function(x)
        return (x.NextLocation == self or not x.NextLocation.isBusy) and x ~= previousAction and All(x.Prerequisites, function(p)
            local li = LastIndexOf(self.History[player:getData('id')], p)
            local lic = LastIndexOf(self.History[player:getData('id')], p.ClosingAction)
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
        lock = false
        return EndStory(player)
    end

    if #nextValidActions > 1 then
        table.remove(nextValidActions, 1)
    end

    if DEBUG_ACTIONS then
        if previousAction then
            str_act = "Actions: Previous action " .. string.sub(previousAction.ActionId, 1, 8) .. "-"
        else
            str_act = "Actions: no previous action - "
        end

        for i, action in ipairs(nextValidActions) do
            str_act = str_act .. string.sub(action.ActionId, 1, 8) .. " "
        end
    end

    return PickRandom(nextValidActions);
end

lock = false
function Location:GetNextValidAction(player)
    if CURRENT_STORY.Disposed then
        return EmptyAction({Performer = player})
    end

    --wait
    while lock do 
        Timer(function()end, 500, 1)
    end
    lock = true
    
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
    if not self.History then
        self.History = {}
    end
    if not self.History[player:getData('id')] then
        self.History[player:getData('id')] = {}
    end
    if not story.History then
        story.History = {}
    end
    if not story.History[player:getData('id')] then
        story.History[player:getData('id')] = {}
    end
    print('Story actions nr '..#(story.History[player:getData('id')]))
    if #(story.History[player:getData('id')]) >= story.MaxActions then
        if DEBUG then
            outputConsole("Location:GetNextValidAction - max story actions reached. Ending the current story")
        end
        lock = false
        return EndStory(player)
    end

    local next = nil
    if not LOAD_FROM_GRAPH then
        print('Get next random valid action')
        next = self:GetNextRandomValidAction(player)
    else
        local q = CURRENT_STORY.actionsQueues[player:getData('id')]
        if #q > 0 then
            next = q[1]
            table.remove(q, 1)
        end
    end

    if not next then
        if DEBUG then
            outputConsole("Location:GetNextValidAction - next action was null. Ending the current story")
            print("Location:GetNextValidAction - next action was null. Ending the current story")
        end
        lock = false
        return EndStory(player)
    else
        if DEBUG then
            outputConsole("Next action chosen: "..next.Description)
            print("Next action chosen: "..next.Description)
        end
        if next.NextLocation == self then
            table.insert(self.History[player:getData('id')], next)
        else
            self.History[player:getData('id')] = {}
            next.NextLocation.History[player:getData('id')] = {next}
            --the actor will change the location
            self.isBusy = false
            next.NextLocation.isBusy = true
            player:setData('locationId', next.NextLocation.LocationId)
        
        end
    end
    lock = false
    next.Performer = player
    return next
end