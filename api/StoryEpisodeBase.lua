StoryEpisodeBase = class(function(o, params)
    o.StoryTimeOfDay = params.storyTimeOfDay or nil
    o.StoryWeather = params.storyWeather or nil
    o.StartingLocation = startingLocation or nil
    o.ValidStartingLocations = {}
    o.Objects = {}
    o.Regions = {}
    o.Disposed = false
    o.CurrentRegion = nil
    o.InteriorId = nil
    o.graphPath = nil
    o.ObjectsToDelete = {}
    o.POI = {}
    o.name = params.name or ""
    o.regionsGroup = nil
    o.pedsNr = params.pedsNr or DEFAULT_PEDS_NR
    o.peds = {}
end)

function StoryEpisodeBase:Initialize(...)
    if not DEFINING_EPISODES then
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
            local regionsInRange = Region.FilterWithinRange(player.position, self.Regions, 1.5)
            local closestRegion = Region.GetClosest(player, regionsInRange, true)
            if closestRegion then
                closestRegion:OnPlayerHit(player)
            end
        end)

        if (self.pedsNr + 1) > #self.ValidStartingLocations then
            if DEBUG then
                outputConsole('[Warning] StoryEpisodeBase:Initialize: number of peds and player is greater than the available starting locations. A max of '..(#self.ValidStartingLocations-1)..' peds will be spawned')
            end
        end
        for i = 1,(self.pedsNr) do
            local validStartingPoi = PickRandom(Where(self.ValidStartingLocations, function(x)
                --find a valid starting location where there are no other players
                return not x.isBusy
            end))
            local skin = PickRandom(Where(SetPlayerSkin.PlayerSkins, function(s)
                return not s.isTaken
            end))
            validStartingPoi.isBusy = true
            local ped = Ped(skin.Id, validStartingPoi.X, validStartingPoi.Y, validStartingPoi.Z, validStartingPoi.Angle)
            ped.interior = validStartingPoi.Interior
            local g = Guid()
            ped:setData("id", g.Id)
            ped:setData("isPed", true)
            ped:setData('startingPoiIdx', LastIndexOf(self.POI, validStartingPoi))
            if not CURRENT_STORY.History[ped:getData('id')] then
                CURRENT_STORY.History[ped:getData('id')] = {}
            end        
            skin.TargetItem = ped
            skin.Performer = ped
            skin:Apply()
            table.insert(self.peds, ped)
        end
    end
end

function StoryEpisodeBase:ProcessRegions()
    if DEBUG then
        outputConsole('StoryEpisodeBase:ProcessRegions - '..self.name..' started to identify which objects are inside which region')
    end
    for i,o in ipairs(self.Objects) do
        if o.instance then
            local r = Region.GetClosest(o, self.Regions, false)
            if r then
                table.insert(r.Objects, o)
                if DEBUG then
                    outputConsole(o.Description..' is inside '..r.name)
                end
            else
                if DEBUG then
                    outputConsole('WARNING! '..o.Description..' is not inside a region')
                end
            end
        end
    end
    if DEBUG then
        outputConsole('StoryEpisodeBase:ProcessRegions - '..self.name..' started to identify which POI are inside which region')
    end
    for i,o in ipairs(self.POI) do
        if o.position then
            local r = Region.GetClosest(o, self.Regions, false)
            if r then
                table.insert(r.POI, o)
                o.Region = r
                if DEBUG then
                    outputConsole(o.Description..' is inside '..r.name)
                end
            else
                if DEBUG then
                    outputConsole('WARNING! '..o.Description..' is not inside a region')
                end
            end
        end
    end
end

function StoryEpisodeBase:Play(...)
end

function StoryEpisodeBase:Destroy()
    if self.regionsGroup then
        self.regionsGroup:destroy() --should also handle the events defined for this element
        self.regionsGroup = nil
    end
    for i,p in ipairs(self.peds) do
        p:destroy()
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

        local objects = {}
        if episode.Objects then
            for k,v in ipairs(episode.Objects) do
                local obj = SampStoryObjectBase(v)
                obj = loadstring(obj.dynamicString)()
                table.insert(objects, obj)
            end
        end
        self.Objects = objects

        if episode.ObjectsToDelete then
            for k,v in ipairs(episode.ObjectsToDelete) do
                local obj = SampStoryObjectBase(v)
                table.insert(self.ObjectsToDelete, obj)
            end
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