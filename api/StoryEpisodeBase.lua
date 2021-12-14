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
    o.peds = {}
    o.supertemplates = params.supertemplates or {}
end)

function StoryEpisodeBase:Initialize(...)
    if not DEFINING_EPISODES then
        local player = nil
        local temporaryInitialize = false
        local requiredActors = nil
        local graphOfEvents = nil
        
        for i,v in ipairs(arg) do
            if i == 1 then
                player = v
            elseif i == 2 then
                temporaryInitialize = v
            elseif i == 3 then
                requiredActors = v
            elseif i == 4 then
                graphOfEvents = v
            end
        end
        if player == nil then
            return false
        end

        if DEBUG then
            print("Episode: Initializing episode "..self.name)
            local str = 'false'
            if temporaryInitialize then str = 'true' end
            print("Episode: Temporary "..str)
            str = 'nil'
            if requiredActors then str = #requiredActors end
            print("Episode: RequiredActors "..str)
        end

        --if we have a graph for paths, then link all possible locations with move actions
        if self.graphId then
            for i,p1 in ipairs(self.POI) do
                --all pois are valid starting locations
                table.insert(self.ValidStartingLocations, p1)
                for j, p2 in ipairs(self.POI) do
                    if i ~= j and p1.LocationId ~= p2.LocationId then
                        local prerequisites = {}
                        if #p1.PossibleActions > 0 then
                            prerequisites = {p1.PossibleActions[1]}
                        end
                        local moveAction = Move{performer = player, targetItem = p2, nextLocation = p2, prerequisites = prerequisites, graphId = self.graphId}
                        table.insert(p1.PossibleActions, moveAction)
                        table.insert(p1.allActions, moveAction)
                        if DEBUG_ACTIONS then
                            print('Move action from '..p1.Description..'to '..p2.Description)
                        end
                    end
                end
                if DEBUG_EPISODE then
                    str_PA = "Episode: Possible move actions for " .. string.sub(p1.LocationId, 1, 8) .. ": "

                    for k,action in ipairs(p1.PossibleActions) do
                        str_PA = str_PA .. string.sub(action.NextLocation.LocationId, 1, 8) .. ", "
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

        --create collision instances for all regions
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

        --Delete objects
        for i,v in ipairs(self.ObjectsToDelete) do
            removeWorldModel(v.modelid, v.size, v.position.x, v.position.y, v.position.z)
        end
        --Create objects
        for i,v in ipairs(self.Objects) do
            v:Create()
        end

        self:ProcessRegions()
        if not temporaryInitialize then
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

            local pedsNr = math.max(math.floor(#self.ValidStartingLocations * ACTORS_CROWDING_FACTOR) - 1, 0)
            if DEBUG then
                local nr = 0
                if requiredActors then
                    nr = #requiredActors
                end
                print('RequiredActors '..nr)
            end
            if requiredActors then
                pedsNr = #requiredActors - 1
            end
            print('Peds nr '..pedsNr)
            if (pedsNr + 1) > #self.ValidStartingLocations then
                if DEBUG then
                    outputConsole('[Warning] StoryEpisodeBase:Initialize: number of peds and player is greater than the available starting locations. A max of '..(#self.ValidStartingLocations-1)..' peds will be spawned')
                end
            end

            for i = 1,(pedsNr) do
                local validStartingPoi = nil
                if not LOAD_FROM_GRAPH then
                    validStartingPoi = PickRandom(Where(self.ValidStartingLocations, function(x)
                        --find a valid starting location where there are no other players
                        return not x.isBusy
                    end))
                else
                    validStartingPoi = {
                        X = 0,
                        Y = 0,
                        Z = 0,
                        Angle = 0,
                        busy = false,
                        LocationId = 'dummyLocationId ---- set later in Process Actions',
                        Description = 'dummyLocationId ---- set later in Process Actions',
                        Interior = 0,
                        dummy = -1
                    }
                    -- local firstEvent = FirstOrDefault(CURRENT_STORY.graph, function(event)
                    --     return event.id == CURRENT_STORY.temporal['starting_actions'][requiredActors[i+1].id]
                    --     -- return event.Actor and event.Actor.id == requiredActors[i+1].id and event.Action ~= 'Exists' and All(Where(CURRENT_STORY.graph, 
                    --     --     function(evt) 
                    --     --         return evt.id ~= event.id and evt.Actor and event.Action ~= 'Exists' and evt.Actor.id == event.Actor.id
                    --     --     end), function(evt)
                    --     --     return evt.Next ~= event.id
                    --     -- end)
                    -- end)
                    -- if not firstEvent then
                    --     error('Could not find the first ped event for actor '..requiredActors[i+1].id)
                    -- elseif DEBUG then
                    --     print('First pred event: '..firstEvent.id..' in location '..firstEvent.Location..' with actor '..firstEvent.Actor.id)
                    -- end
                    -- validStartingPoi = FirstOrDefault(self.POI, function(poi) 
                    --     return not poi.isBusy and poi.Region.name:lower():find(firstEvent.Location:lower()) and true or false 
                    --         and Any(poi.allActions, function(a) 
                    --             return a.Name:lower() == firstEvent.Action:lower()
                    --             and a.TargetItem.ObjectId and a.TargetItem.type == CURRENT_STORY.graph[firstEvent.Target.id].Target.Name --action has a target an object of type x
                    --             and a.TargetItem.ObjectId == reverseObjectMap[firstEvent.Target.id]            
                    --         end) 
                    -- end)
                end
                if not validStartingPoi then
                    error('A valid starting point could not be found for ped '..i)
                elseif DEBUG then
                    print('Valid starting ped point '..validStartingPoi.LocationId..': '..validStartingPoi.Description)
                end
                local skin = PickRandom(Where(SetPlayerSkin.PlayerSkins, function(s)
                    return not s.isTaken and(not requiredActors or requiredActors[i+1].Properties.Gender == s.Gender )
                end))
                if not skin then
                    error('A valid skin could not be found for ped '..i)
                end
                validStartingPoi.isBusy = true
                local ped = PedHandler:GetOrCreatePed(skin.Id, validStartingPoi.X, validStartingPoi.Y, validStartingPoi.Z, validStartingPoi.Angle)
                if not ped then
                    error('Error while creating the ped '..i)
                end
                ped.interior = validStartingPoi.Interior
                local g = Guid()
                ped:setData("id", i..'')
                ped:setData("isPed", true)
                ped:setData('startingPoiIdx', validStartingPoi.dummy or LastIndexOf(self.POI, validStartingPoi))
                skin.TargetItem = ped
                skin.Performer = ped
                if requiredActors then
                    skin:Apply(requiredActors[i+1].Properties) --changes the actor id, name, gender
                else
                    skin:Apply()
                end
                if not CURRENT_STORY.History[ped:getData('id')] then
                    CURRENT_STORY.History[ped:getData('id')] = {}
                end
                table.insert(self.peds, ped)
            end
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
                o.Region = r
                if DEBUG then
                    print(o.ObjectId..': '..o.Description..' is inside '..r.name)
                end
            else
                if DEBUG then
                    print('WARNING! '..o.ObjectId..': '..o.Description..' is not inside a region')
                end
            end
        end
    end
    if DEBUG then
        print('StoryEpisodeBase:ProcessRegions - '..self.name..' started to identify which POI are inside which region')
    end
    for i,o in ipairs(self.POI) do
        if o.position then
            local r = Region.GetClosest(o, self.Regions, false)
            if r then
                table.insert(r.POI, o)
                o.Region = r
                if DEBUG then
                    print(o.Description..' is inside '..r.name)
                end
            else
                if DEBUG then
                    print('WARNING! '..o.Description..' is not inside a region')
                end
            end
        end
    end
end

function StoryEpisodeBase:Play(...)
    if not LOAD_FROM_GRAPH then
        StoryEpisodeBase.ProcessRegions(self)
    end
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    if self.StartingLocation == nil then
        if not LOAD_FROM_GRAPH then
            self.StartingLocation = PickRandom(Where(self.ValidStartingLocations, function(x)
                return not x.isBusy
            end))
        else
            -- --find the first event for the current actor
            -- local firstEvent = FirstOrDefault(CURRENT_STORY.graph, function(event)
            --     return event.id == CURRENT_STORY.temporal['starting_actions'][player:getData('id')]
            --     -- event.Actor and event.Actor.id == player:getData('id') and event.Action ~= 'Exists' and All(Where(CURRENT_STORY.graph, 
            --     --     function(evt) 
            --     --         return evt.id ~= event.id and evt.Actor and event.Action ~= 'Exists' and evt.Actor.id == event.Actor.id
            --     --     end), function(evt)
            --     --     return evt.Next ~= event.id
            --     -- end)
            -- end)
            -- if not firstEvent then
            --     error('Could not find the first event for actor '..player:getData('id'))
            -- elseif DEBUG then
            --     print('First event: '..firstEvent.id..' in location '..firstEvent.Location..' with actor '..firstEvent.Actor.id)
            -- end
            -- self.StartingLocation = FirstOrDefault(self.POI, function(poi) 
            --     return poi.Region.name:lower():find(firstEvent.Location:lower()) and true or false 
            --         and Any(poi.allActions, function(a) return a.Name:lower() == firstEvent.Action:lower()
            --         and a.TargetItem.ObjectId and a.TargetItem.type == CURRENT_STORY.graph[firstEvent.Target.id].Target.Name --action has a target an object of type x
            --         and a.TargetItem.ObjectId == reverseObjectMap[firstEvent.Target.id]    
            --         end) 
            -- end)
            if not self.StartingLocation then
                error('StoryEpisodeBase:Play Could not find a starting location in region '..firstEvent.Location)
            elseif DEBUG then
                print('First location: '..self.StartingLocation.LocationId..self.StartingLocation.Description)
            end
        end
    end
    self.StartingLocation:SpawnPlayerHere(player)
    if DEBUG then
        outputConsole(self.name..":Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
end

function StoryEpisodeBase:Destroy()
   -- outputChatBox(self)
   -- outputChatBox(CURRENT_STORY)
    --for _, ped in ipairs(self.peds) do
     --   outputChatBox(CURRENT_STORY)
      --  CURRENT_STORY.Logger:FlushBuffer(ped, true)
    --end
   -- CURRENT_STORY.Logger:FlushBuffer(CURRENT_STORY.Actor, true)

    if self.regionsGroup then
        self.regionsGroup:destroy() --should also handle the events defined for this element
        self.regionsGroup = nil
    end

    if self.peds then
        for i,p in ipairs(self.peds) do
            if isElement(p) then
                p.interior = 0
                p.position = Vector3(0,0,0)
            end
        end
        print('reinitializing peds')
        PedHandler:ReInitialize()
    end

    self.Disposed = true
end

function StoryEpisodeBase:ReloadPathGraph()
    if self.graphPath then
        if unloadPathGraph then
            unloadPathGraph(self.graphId)
        end
        if loadPathGraph then
            self.graphId = loadPathGraph(self.graphPath)
        end
    end
    for _, poi in pairs(self.POI) do
        for _, a in pairs(poi.allActions) do
            if a.graphId then
                a.graphId = self.graphId
            end
        end
    end
end

function StoryEpisodeBase:Reset()
    self.StoryTimeOfDay = nil
    self.StoryWeather = nil
    self.StartingLocation = nil
    self.ValidStartingLocations = {}
    self.Objects = {}
    self.Regions = {}
    self.Disposed = false
    self.CurrentRegion = nil
    self.InteriorId = nil
    self.graphPath = nil
    self.ObjectsToDelete = {}
    self.POI = {}
    self.name = params.name or ""
    self.regionsGroup = nil
    self.peds = {}
    self.supertemplates = {}
end

function StoryEpisodeBase:LoadFromFile()
    if DEBUG then
        print("Episode: Loading episode from "..self.name.. ".json")
    end

    local file = fileOpen("files/episodes/"..self.name..".json") 
    if file then
        local jsonStr = fileRead(file, fileGetSize(file))
        local episode = fromJSON(jsonStr)
        fileClose(file)
        
        if DEBUG then
            print("Episode: Setting the graph path to ".. episode.graphPath)
        end

        self.InteriorId = episode.InteriorId
        self.graphPath = episode.graphPath
        if self.graphPath then
            if loadPathGraph then
                self.graphId = loadPathGraph(self.graphPath)
            end
        end

        if DEBUG then
            print("Episode: Setting the time of the day")
        end

        self.name = episode.name
        if (episode.StoryTimeOfDay) then --TODO: set random if required
            self.StoryTimeOfDay = TimeOfDay(episode.StoryTimeOfDay.hour, episode.StoryTimeOfDay.minute)
        end
        if (episode.StoryWeather) then --TODO: set random if required
            self.StoryWeather = Weather(episode.StoryWeather.id, episode.StoryWeather.description)
        end

        if DEBUG then
            print("Episode: Setting the objects in the environment")
        end

        local objects = {}
        if episode.Objects then
            for k,v in ipairs(episode.Objects) do
                local obj = SampStoryObjectBase(v)
                obj = loadstring(obj.dynamicString)()
                obj.ObjectId = k..''
                table.insert(objects, obj)
            end
        end
        self.Objects = objects
        
        if DEBUG then
            print("Episode: Deleting the removed objects from the environemnt")
        end
        if episode.ObjectsToDelete then
            for k,v in ipairs(episode.ObjectsToDelete) do
                local obj = SampStoryObjectBase(v)
                table.insert(self.ObjectsToDelete, obj)
            end
        end
        
        if DEBUG then
            print("Episode: Setting the points of interest and their actions")
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
            obj.LocationId = k..''
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
                        deserializedAllActions[a.closingAction.id].IsClosingAction = true
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
                deserialized.Id = i..''
                table.insert(self.Regions, deserialized)
            end
        end

        if episode.supertemplates then
            math.randomseed(os.clock()*100000000000)
            math.random(); math.random(); math.random()
            math.randomseed(os.clock()*100000000000)
            math.random(); math.random(); math.random()
        
            for _, s in ipairs(episode.supertemplates) do
                local idx = math.random(#s.templates)
                if not s.offsets[idx].skip then
                    local template = Template.Load(s.name, s.templates[idx])
                    template:Instantiate(episode.InteriorId, Vector3(s.position.x, s.position.y, s.position.z))
                    s.instantiatedTemplate = template
                    local offsets = s.offsets[idx]
                    template:UpdatePosition(Vector3(offsets.offset.x, offsets.offset.y, offsets.offset.z))
                    template:UpdatePosition(nil, Vector3(offsets.rotationOffset.x, offsets.rotationOffset.y, offsets.rotationOffset.z), Vector3(s.position.x, s.position.y, s.position.z), true)
                    if not DEFINING_EPISODES then
                        template:InsertInEpisode(self, true)
                    end
                end
            end
        end
        if DEFINING_EPISODES then
            self.supertemplates = episode.supertemplates
        end
        return true
    else 
        return false
    end
end