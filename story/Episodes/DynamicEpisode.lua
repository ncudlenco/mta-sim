DynamicEpisode = class(StoryEpisodeBase, function(o, name)
    StoryEpisodeBase.init(o, nil, nil, nil)
    
    o.InteriorId = nil
    o.graphPath = nil
    o.ObjectsToDelete = {}
    o.POI = {}
    o.name = name or ""
end)


function DynamicEpisode:Initialize(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end
    --Delete objects
    for i,v in ipairs(self.ObjectsToDelete) do
        removeWorldModel(v.modelid, v.size, v.position.x, v.position.y, v.position.z)
    end
    --Create objects
    for i,v in ipairs(self.Objects) do
        v:Create()
    end

    if self.graphId then
        for i,p1 in ipairs(self.POI) do
            table.insert(self.ValidStartingLocations, p1)
            for j, p2 in ipairs(self.POI) do
                if i ~= j then
                    local prerequisites = {}
                    if #p1.PossibleActions > 0 then
                        prerequisites = {p1.PossibleActions[1]}
                    end
                    table.insert(p1.PossibleActions, Move{performer = player, targetItem = p2, nextLocation = p2, prerequisites = prerequisites, graphId = self.graphId})
                end
            end
        end
    end

    for _,poi in ipairs(self.POI) do
        if poi.allActions then
            for _,a in ipairs(poi.allActions) do
                a.Performer = player
            end
        end
    end
end

function DynamicEpisode:Play(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    if self.StartingLocation == nil then
        self.StartingLocation = PickRandom(self.POI)
    end
    self.StartingLocation:SpawnPlayerHere(player)
    if DEBUG then
        outputConsole(self.name..":Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
end

function DynamicEpisode:Destroy()
    for _,item in ipairs(self.Objects) do
        item:Destroy()
    end
    if unloadPathGraph and self.graphId then
        unloadPathGraph(self.graphId)
    end
    if DEBUG then
        outputConsole(self.name..":Destroyed")
    end
    StoryEpisodeBase.Destroy(self)
end

function DynamicEpisode:LoadFromFile()
    file = fileOpen("files/episodes/"..self.name..".json") 
    if file then
        local jsonStr = fileRead(file, fileGetSize(file))
        local episode = fromJSON(jsonStr)
        fileClose(file)

        self.InteriorId = episode.InteriorId
        self.graphPath = episode.graphPath
        if self.graphPath then
            if loadPathGraph then
                self.graphId = loadPathGraph(self.graphPath)
            end
        end

        self.name = episode.name
        if (episode.StoryTimeOfDay) then --TODO: set random if required
            self.StoryTimeOfDay = TimeOfDay(episode.StoryTimeOfDay.hour, episode.StoryTimeOfDay.minute)
        end
        if (episode.StoryWeather) then --TODO: set random if required
            self.StoryWeather = Weather(episode.StoryWeather.id, episode.StoryWeather.description)
        end

        local objects = {}
        for k,v in ipairs(episode.Objects) do
            local obj = SampStoryObjectBase(v)
            obj = loadstring(obj.dynamicString)()
            table.insert(objects, obj)
        end
        self.Objects = objects

        for k,v in ipairs(episode.ObjectsToDelete) do
            local obj = SampStoryObjectBase(v)
            table.insert(self.ObjectsToDelete, obj)
        end

        local deserializedPOI = {}
        for k,v in ipairs(episode.POI) do
            local obj = Location(v.X, v.Y, v.Z, v.Angle, v.Interior, v.Description)
            if v.allActions then
                obj.allActions = v.allActions
            end
            if v.PossibleActions then
                obj.PossibleActions = v.PossibleActions
            end
            table.insert(deserializedPOI, obj)
        end
        self.POI = deserializedPOI
        for k,poi in ipairs(self.POI) do
            if poi.allActions then
                local deserializedAllActions = {}
                for _,a in ipairs(poi.allActions) do
                    local actionInstance = loadstring(a.dynamicString)()
                    actionInstance.id = a.id
                    --target item
                    local targetItem = nil
                    if a.targetItem.id > 0 then
                        if a.targetItem.type == "Object" then
                            targetItem = self.Objects[a.targetItem.id]
                        elseif a.targetItem.type == "Location" then
                            targetItem = self.POI[a.targetItem.id]
                        end
                    end
                    actionInstance.TargetItem = targetItem
                    actionInstance.NextLocation = self.POI[a.nextLocation.id]
                    table.insert(deserializedAllActions, actionInstance)
                end
                for idx,a in ipairs(poi.allActions) do
                    --next action
                    if a.nextAction then
                        if isArray(a.nextAction) then
                            if #a.nextAction == 1 then
                                deserializedAllActions[idx].NextAction = deserializedAllActions[a.nextAction[1].id]
                            elseif #a.nextAction > 1 then
                                deserializedAllActions[idx].NextAction = {}
                                for _,na in ipairs(a.nextAction) do
                                    table.insert(deserializedAllActions[idx].NextAction, deserializedAllActions[na.id])
                                end
                            end
                        else
                            deserializedAllActions[idx].NextAction = deserializedAllActions[a.nextAction.id]
                        end
                    end
                    if a.closingAction then
                        deserializedAllActions[idx].ClosingAction = deserializedAllActions[a.closingAction.id]
                    end
                end
                poi.allActions = deserializedAllActions
                local deserializedPossibleActions = {}
                if poi.PossibleActions then
                    for _,pa in ipairs(poi.PossibleActions) do
                        table.insert(deserializedPossibleActions, poi.allActions[pa.id])
                    end
                end
                poi.PossibleActions = deserializedPossibleActions
            end
        end
        return true
    else 
        return false
    end
end