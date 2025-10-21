StoryEpisodeBase = class(function(o, params)
    o.StoryTimeOfDay = params.storyTimeOfDay or nil
    o.StoryWeather = params.storyWeather or nil
    o.ValidStartingLocations = {}
    o.Objects = {}
    o.Regions = {}
    o.Disposed = false
    o.CurrentRegion = nil
    o.InteriorId = nil
    o.graphPath = nil
    o.pathfindingGraph = nil
    o.ObjectsToDelete = {}
    o.POI = {}
    o.name = params.name or ""
    o.regionsGroup = nil
    o.peds = {}
    o.supertemplates = params.supertemplates or {}
    o.temporaryInitialized = false
    o.initialized = false
end)

function StoryEpisodeBase:__eq(other)
    return other and other:is_a(StoryEpisodeBase) and self.name == other.name and self.InteriorId == other.InteriorId
end

function StoryEpisodeBase:Initialize(...)
    if not DEFINING_EPISODES then
        local temporaryInitialize = false
        local requiredActors = nil
        local graphOfEvents = nil

        for i,v in ipairs(arg) do
            if i == 1 then
                temporaryInitialize = v
            elseif i == 2 then
                requiredActors = v
            elseif i == 3 then
                graphOfEvents = v
            end
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

        if not self.temporaryInitialized and true or false then
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
            print("Deleting world models...")
            for i,v in ipairs(self.ObjectsToDelete) do
                removeWorldModel(v.modelid, v.size, v.position.x, v.position.y, v.position.z)
            end
            --Create objects
            for i,v in ipairs(self.Objects) do
                v:Create()
            end

            self:ProcessRegions()

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
                            local moveAction = Move{targetItem = p2, nextLocation = p2, prerequisites = prerequisites, graphId = self.graphId}
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
            self.temporaryInitialized = true
        else
            print("SKIPPING EPISODE "..self.name..' temporary initialization because its already initialized')
        end
        if not temporaryInitialize and (not self.initialized and true or false) then
            for _, value in ipairs(self.POI) do
                value.isBusy = false
            end

            addEventHandler( "onColShapeHit", self.regionsGroup, function(player)
                if not player:getData('isPed') then
                    return
                end
                if DEBUG then
                    outputConsole('[StoryEpisodeBase:Initialize] Regions group hit')
                end
                local regionsInRange = Region.FilterWithinRange(player.position, self.Regions, 2)
                local closestRegion = Region.GetClosest(player, regionsInRange, true)
                if DEBUG and closestRegion then
                    print("Warning: Closest reagion for the player "..player:getData('id')..' is '..(closestRegion.name or 'null'))
                elseif DEBUG then
                    print('WARNING! Player '..player:getData('id')..' is not inside a region')
                end
                local startingPoiIdx = player:getData('startingPoiIdx')
                if not closestRegion then
                    if not player:getData('spawned') and startingPoiIdx and startingPoiIdx < #CURRENT_STORY.CurrentEpisode.POI then
                        closestRegion = CURRENT_STORY.CurrentEpisode.POI[startingPoiIdx].Region
                        if DEBUG then
                            print("Warning: No region was found in range for the player "..player:getData('id')..' but took one from the starting POI '..(closestRegion.name or 'null'))
                        end
                    end
                end
                player:setData('spawned', true)
                if not closestRegion then
                    closestRegion = PickRandom(self.Regions)
                    if DEBUG and closestRegion then
                        print("Warning: No region was found in range for the player "..player:getData('id')..'. Randomly picked '..(closestRegion.name or 'null'))
                    end
                end
                if closestRegion then
                    closestRegion:OnPlayerHit(player)
                elseif DEBUG then
                    print("FATAL ERROR: No region was found in range, in starting location or random for the player "..player:getData('id'))
                end
            end)

            local pedsNr = math.max(math.floor(#self.ValidStartingLocations * ACTORS_CROWDING_FACTOR), 1)
            if RANDOM_ACTORS_NR then
                local maxNr = math.min(MAX_ACTORS, #self.ValidStartingLocations)
                pedsNr = math.random(MIN_ACTORS, maxNr)
            end
            if DEBUG then
                local nr = 0
                if requiredActors then
                    nr = #requiredActors
                end
                print('RequiredActors '..nr)
            end
            if requiredActors then
                pedsNr = #requiredActors
            end
            print('Peds nr '..pedsNr)
            if pedsNr > #self.ValidStartingLocations then
                if DEBUG then
                    outputConsole('[Warning] StoryEpisodeBase:Initialize: number of peds is greater than the available starting locations. A max of '..(#self.ValidStartingLocations-1)..' peds will be spawned')
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
                        isBusy = false,
                        LocationId = 'dummyLocationId ---- set later in Process Actions',
                        Description = 'dummyLocationId ---- set later in Process Actions',
                        Interior = 0,
                        dummy = -1
                    }
                end
                if not validStartingPoi then
                    error('A valid starting point could not be found for ped '..i)
                elseif DEBUG then
                    print('Valid starting ped point '..validStartingPoi.LocationId..': '..validStartingPoi.Description)
                end
                local skin = PickRandom(Where(SetPlayerSkin.PlayerSkins, function(s)
                    return s and not s.isTaken and(not requiredActors or requiredActors[i].Properties.Gender == s.Gender )
                end))
                if not skin then
                    error('A valid skin could not be found for ped '..i)
                end
                validStartingPoi.isBusy = true
                print('[StoryEpisodeBase.Initialize] Location '..validStartingPoi.Description..' is set to busy')
                local ped = PedHandler:GetOrCreatePed(skin.Id, validStartingPoi.X, validStartingPoi.Y, validStartingPoi.Z, validStartingPoi.Angle)
                if not ped then
                    error('Error while creating the ped '..i)
                end
                ped.interior = validStartingPoi.Interior
                local g = Guid()
                ped:setData("id", i..'')
                ped:setData("isPed", true)
                ped:setData('startingPoiIdx', validStartingPoi.dummy or LastIndexOf(self.POI, validStartingPoi))
                if validStartingPoi.Region then
                    if DEBUG then
                        print('[StoryEpisodeBase - actor inintialization]: currentRegion: '..(validStartingPoi.Region.name or 'null')..
                            ' currentRegionId: '..(validStartingPoi.Region.Id or 'null')..
                            ' currentEpisode: '..(validStartingPoi.Region.Episode.name or 'null')
                        )
                    end
                    ped:setData('currentRegion', validStartingPoi.Region.name)
                    ped:setData('currentRegionId', validStartingPoi.Region.Id)
                    ped:setData('currentEpisode', validStartingPoi.Region.Episode.name)
                end
                skin.TargetItem = ped
                skin.Performer = ped
                if requiredActors then
                    skin:Apply(requiredActors[i].Properties) --changes the actor id, name, gender
                else
                    skin:Apply()
                end
                if not CURRENT_STORY.History[ped:getData('id')] then
                    CURRENT_STORY.History[ped:getData('id')] = {}
                end
                table.insert(self.peds, ped)
            end
            self.initialized = true
        else
            print("SKIPPING EPISODE "..self.name..' initialization because its already initialized')
        end
    else
        --Delete objects
        print("Deleting world models...")
        for i,v in ipairs(self.ObjectsToDelete) do
            removeWorldModel(v.modelid, v.size, v.position.x, v.position.y, v.position.z)
        end
        --Create objects
        for i,v in ipairs(self.Objects) do
            v:Create()
        end
    end
end

function StoryEpisodeBase:ProcessRegions()
    if DEBUG and DEBUG_PROCESSREGIONS then
        print('StoryEpisodeBase:ProcessRegions - '..self.name..' started to identify which objects are inside which region')
        outputConsole('StoryEpisodeBase:ProcessRegions - '..self.name..' started to identify which objects are inside which region')
    end
    for i,o in ipairs(self.Objects) do
        if o.instance then
            local r = Region.GetClosest(o, self.Regions, false)
            if r then
                table.insert(r.Objects, o)
                o.Region = r
                if DEBUG and DEBUG_PROCESSREGIONS then
                    print(o.ObjectId..': '..o.Description..' is inside '..r.name)
                end
            else
                if DEBUG then
                    print('WARNING! Object '..o.ObjectId..': '..o.Description..' is not inside a region')
                end
            end
        end
    end
    if DEBUG and DEBUG_PROCESSREGIONS then
        print('StoryEpisodeBase:ProcessRegions - '..self.name..' started to identify which POI are inside which region')
    end
    local poisWithRegions = {}
    for i,o in ipairs(self.POI) do
        if o.position then
            local r = Region.GetClosest(o, self.Regions, false) or Region.GetClosestByVertex(o, self.Regions)
            if r then
                table.insert(r.POI, o)
                table.insert(poisWithRegions, o)
                o.Region = r
                if DEBUG and DEBUG_PROCESSREGIONS then
                    print(o.Description..' is inside '..r.name)
                end
            else
                print('WARNING! POI '..o.Description..' is not inside a region for episode '..self.name)
            end
        end
    end
    self.POI = poisWithRegions
    if self.graphId and self.pathfindingGraph then
        for i,node in ipairs(self.pathfindingGraph) do
            node.position = Vector3(node.x, node.y, node.z)
            local r = Region.GetClosest(node, self.Regions, false)
            if r then
                node.Region = r
            else
                print('WARNING! PATHFINDING node '..i..' is not inside a region for episode '..self.name)
            end
        end
    end
    self.processedRegions = true
end

function StoryEpisodeBase:Play(...)
    if not LOAD_FROM_GRAPH then
        StoryEpisodeBase.ProcessRegions(self)
    end

    for i,spectator in ipairs(getElementsByType('player')) do
        if not FREE_ROAM then
            spectator:setAlpha(0)
            -- spectator:setCollisionsEnabled(false) -- doesn't work
            spectator:setGravity(0)
        end
        if self:is_a(MetaEpisode) then
            if i <= #self.Episodes then --Try to assign a spectator to each episode.
                self.Episodes[i].POI[#self.Episodes[i].POI]:SpawnPlayerHere(spectator, true) --assign real players to each episode. TODO: replace with the save snapshot logic
            end
        else
            self.POI[#self.POI]:SpawnPlayerHere(spectator)
        end
    end

    if DEBUG then
        outputConsole(self.name..":Play. Spawn scheduled for all spectators.")
    end
end

function StoryEpisodeBase:Destroy()
    if self.regionsGroup then
        self.regionsGroup:destroy() --should also handle the events defined for this element
        self.regionsGroup = nil
    end

    if self.peds then
        for i,p in ipairs(self.peds) do
            FirstOrDefault(CURRENT_STORY.Loggers):FlushBuffer(p, true)
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
            local otherFile = fileOpen(self.graphPath)
            if otherFile then
                local jsonStr = fileRead(otherFile, fileGetSize(otherFile))
                self.pathfindingGraph = fromJSON("["..jsonStr.."]")
                fileClose(otherFile)
            end
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
                local otherFile = fileOpen(self.graphPath)
                if otherFile then
                    local jsonStr = fileRead(otherFile, fileGetSize(otherFile))
                    self.pathfindingGraph = fromJSON("["..jsonStr.."]")
                    fileClose(otherFile)
                end
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
                local obj = loadstring(v.dynamicString)()
                obj.ObjectId = k..'_'..self.name
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
            obj.interactionsOnly = v.interactionsOnly or false
            if obj.interactionsOnly then
                print('Deserialized location with interactions only '..obj.Description)
            end
            obj.LocationId = k..'_'..self.name
            obj.episodeLinks = v.episodeLinks or {}
            obj.Episode = self
            obj.isBusy = false
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
                    if actionInstance.name == 'Move' then
                        actionInstance.graphId = self.graphId
                    end
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
                deserialized.Id = i..'_'..self.name
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
                    -- The check is needed when defining episodes because otherwise all the objects inserted from the supertemplate will also be saved, resulting in overlaping objects when loading.
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

function StoryEpisodeBase:RequestPause()
    for _, actor in ipairs(self.peds) do
        if not actor:getData('storyEnded')
            and actor:getData('currentEpisode') == self.name
            and not actor:getData('isAwaitingConstraints')
            then
            if DEBUG then
                print('actor '..actor:getData('id')..' is in old focused episode')
            end
            if #CURRENT_STORY.History[actor:getData('id')] > 0 then
                local lastAction = CURRENT_STORY.History[actor:getData('id')][#CURRENT_STORY.History[actor:getData('id')]]
                local isMove = 'false'
                if lastAction:is_a(Move) then
                    isMove = 'true'
                end
                local isMoveActionFinished = 'false'
                if lastAction:is_a(Move) and lastAction:isFinished(actor) then
                    isMoveActionFinished = 'true'
                end
                if DEBUG then
                    print('Requesting pause for actor '..actor:getData('id')..' last action '..lastAction.Name..' (is a move action: '..isMove..') is not finished: '..isMoveActionFinished)
                end

                actor:setData('requestPause', true) -- Handled in ActionsGlobals.OnGlobalActionFinished and in Move:pause
                if lastAction:is_a(Wait) then
                    lastAction:pause(actor)
                end
                -- if lastAction:is_a(Move) and not lastAction:isFinished(actor) then
                --     lastAction:pause(actor)
                --     --Make sure some time will be allocated to this actor afterwards
                --     CURRENT_STORY.CameraHandler:requestFocus(actor:getData('id'))
                --     print('actor '..actor:getData('id')..' is now paused and has a focus request prepped')
                -- end
            end
        end
    end
    self.paused = true
end

function StoryEpisodeBase:AreAllActionsPaused(forcePause)
    return All(
        Where(self.peds,
            function(ped) return ped:getData('currentEpisode') == self.name and not ped:getData('storyEnded') end),
        function(ped)
            local isAwaitingConstraints = ped:getData('isAwaitingConstraints')
            local isPaused = ped:getData('paused')
            if DEBUG then
                print('Checking if actor ' .. ped:getData('id') .. ' is paused ' .. tostring(isPaused) .. ' is awaiting constraints ' .. tostring(isAwaitingConstraints))
            end
            if forcePause then
                ped:setData('requestPause', false)
                ped:setData('paused', true)
                isPaused = true
            end

            return isPaused or isAwaitingConstraints
        end)
end

function StoryEpisodeBase:Resume()
    for _, actor in ipairs(self.peds) do
        if DEBUG then
            print('[StoryEpisodeBase:Resume] Evaluating actor '..actor:getData('id')..' from episode '..actor:getData('currentEpisode')..' with storyEnded '..tostring(actor:getData('storyEnded'))..' and currentEpisode '..actor:getData('currentEpisode')..' and requestPause '..tostring(actor:getData('requestPause'))..' and paused '..tostring(actor:getData('paused'))..' and isAwaitingConstraints '..tostring(actor:getData('isAwaitingConstraints'))..' and isAwaitingContextSwitch '..tostring(actor:getData('isAwaitingContextSwitch')))
        end
        if actor:getData('currentEpisode') == self.name and not actor:getData('storyEnded') then
            actor:setData('requestPause', false)
            if DEBUG then
                print('Actor '..actor:getData('id')..' reset the requestPause parameter. History length '..#CURRENT_STORY.History[actor:getData('id')])
            end
            if not actor:getData('isAwaitingConstraints') and actor:getData('paused') and #CURRENT_STORY.History[actor:getData('id')] > 0 then
                if DEBUG then
                    print('Actor '..actor:getData('id')..' is in episode '..actor:getData('currentEpisode')..' and is not awaiting constraints')
                end
                local lastAction = CURRENT_STORY.History[actor:getData('id')][#CURRENT_STORY.History[actor:getData('id')]]
                if lastAction:is_a(Move) then
                    CURRENT_STORY.CameraHandler:requestFocus(actor:getData('id')) --reduntant focus requests
                    lastAction:resume(actor)
                elseif lastAction:is_a(Wait) then
                    lastAction:resume(actor)
                else
                    if DEBUG then
                        print('Resuming actor '..actor:getData('id')..' from '..lastAction.Name)
                    end
                    OnGlobalActionFinished(1, actor:getData('id'), actor:getData('storyId'))
                end
            elseif actor:getData('isAwaitingContextSwitch') then
                if DEBUG then
                    print('Actor '..actor:getData('id')..' is awaiting isAwaitingContextSwitch')
                end
                CURRENT_STORY.ActionsOrchestrator:TriggerActionFromQueue(actor)
            end
            actor:setData('paused', false)
        end
    end
    self.paused = false
end