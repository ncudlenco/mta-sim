StoryEpisodeBase = class(function(o, name, storyTimeOfDay, storyWeather, startingLocation)
    o.StoryTimeOfDay = storyTimeOfDay
    o.StoryWeather = storyWeather
    o.StartingLocation = startingLocation
    o.ValidStartingLocations = {}
    o.Objects = {}
    o.Regions = {}
    o.Disposed = false
    o.Regions = {}
    o.InteriorId = nil
    o.graphPath = nil
    o.ObjectsToDelete = {}
    o.POI = {}
    o.name = name or ""
    o.cameras = {}
    o.regionsGroup = nil
end)

function StoryEpisodeBase:Initialize(...)
    self.regionsGroup = createElement("regions")
    for i,region in ipairs(self.Regions) do
        local coords = {region.center.x, region.center.y}
        for j,v in ipairs(region.vertexes) do
            table.insert(coords, v.x)
            table.insert(coords, v.y)
        end
        local regionCollisionInstance = createColPolygon(unpack(coords))
        if DEBUG and not regionCollisionInstance then
            outputConsole("StoryEpisodeBase:Initialize - [ERROR] Could not create a collision instance "..i)
        end
        if regionCollisionInstance then
            region.instance = regionCollisionInstance
            setElementParent(regionCollisionInstance, self.regionsGroup)
        end
    end
    addEventHandler( "onColShapeHit", self.regionsGroup, function(player)
        if DEBUG then
            outputConsole('StoryEpisodeBase:Initialize - Region hit')
        end
        local closestRegion = Region.GetClosest(player, self.Regions, true)
        if closestRegion then
            closestRegion:OnPlayerHit(player)
        end
    end)
end

function StoryEpisodeBase:Play(...)
end

function StoryEpisodeBase:Destroy()
    if self.regionsGroup then
        self.regionsGroup:destroy() --should also handle the events defined for this element
        self.regionsGroup = nil
    end
    self.Disposed = true
end

function StoryEpisodeBase:LoadFromFile()
    local file = fileOpen("files/episodes/"..self.name..".json") 
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

        self.cameras = episode.cameras

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

        if episode.Regions then
            self.Regions = {}
            for i, region in ipairs(episode.Regions) do
                local deserialized = Region(region)
                deserialized.Episode = self
                table.insert(self.Regions, deserialized)
            end
        end
        return true
    else 
        return false
    end
end