GraphStory = class(StoryBase, function(o, actor, logData)
    StoryBase.init(o, actor, maxActions)
    o.LogData = logData
    o.Logger = Logger('data/'..o.Id..'/'..actor:getData('id'), true, o)
    o.AllEpisodes = {
        House1(),
        House3(),
        House8(),
        House10(),
        House12()
    }
    o.Episodes = {
        House1(),
        House3(),
        House8(),
        House10(),
        House12()
    }
    o.DynamicEpisodes = {
      "house1_sweet",
      "house7",
    --   "house8",
      "house9",
    --   "house10",
    --   "house12",
      "gym1",
      "gym2",
      "gym3"
    }
    o.Disposed = false
    o.SpawnableObjects = {
        "Cigarette",
        "MobilePhone"
    }
    o.Interactions = {
        "Handshake",
        "Talk",
        "Kiss",
        "Hug",
        "Laugh"
    }
    o.MaxActions = 9999
    o.actionsQueues = {}
    if not o.Actor then
        outputConsole("Error: Actor is null "..o.Id..'/'..actor:getData('id'))
    end
    o.Actor:setData('storyId', o.Id)
    o.graph = nil
    o.temporal = nil
    o.lastEvents = {}
    o.lastLocations = {}
    local file = fileOpen(LOAD_FROM_GRAPH)
    if file then
        local outputFolder = LOAD_FROM_GRAPH..'_out/'..o.Id
        o.Logger = Logger(outputFolder, true, o)
        
        local jsonStr = fileRead(file, fileGetSize(file))
        o.graph = fromJSON(jsonStr)
        fileClose(file)
        if o.graph['temporal'] then
            o.temporal = o.graph['temporal']
            o.graph['temporal'] = nil
        end
        if o.graph['temporal_abs'] then
            o.graph['temporal_abs'] = nil
        end
        for k,v in pairs(o.graph) do
            if v.Action then
                v.id = k
            end
        end
        
        if DEBUG then
            print("GraphStory: read the file graph.json")
        end
    end

    CURRENT_STORY = o
end)

function GraphStory:GetValidEpisodes()
    if DEBUG then
        print("GraphStory:GetValidEpisodes: loading all available episodes in memory")
    end
    for i,episode_name in ipairs(self.DynamicEpisodes) do
        print(episode_name)
        local episode = DynamicEpisode(episode_name)
        local success = episode:LoadFromFile()

        table.insert(self.Episodes, episode)
    end

    --first preprocess the graph and extract the requirements:
    --a list of all the locations
    if DEBUG then
        print("GraphStory:GetValidEpisodes: retrieving a list of all the locations in the input graph")
    end
    local requiredLocations = Where(UniqueStr(Flatten(Select(Where(self.graph, function(event)
        return event.Location and true or false --converts to bool 
    end), function(event)
        return event.Location
    end))), function(item) return item and item ~= "" end)
    if DEBUG then
        for _,v in pairs(requiredLocations) do
            print(v)
        end
    end
--a list of all the objects and their locations (temporary objects i.e. cigarette should not be checked )
    local requiredObjects = Select(Where(self.graph, function(event)
        return event.Action == 'Exists' and not event.Properties.Gender
    end), function(event)
        local location = ''
        if event.Location and #event.Location > 0 then location = event.Location[1] end
        return { location = location, name = event.Properties.Name, id = event.id }
    end)
    --a list of all the actions and their locations (a POI is placed in a location, in a POI I have allActions)
    local requiredActions = Select(Where(self.graph, function(event)
        return event.Action ~= 'Exists'
    end), function(event)
        local target = nil
        if #event.Entities > 1 then target = event.Entities[2] end
        local location = ''
        if event.Location and #event.Location > 0 then location = event.Location[1] end
        return { location = location, name = event.Action, target = target }
    end)

    local validEpisodes = {}

    for i,episode in ipairs(self.Episodes) do
        --first: see if the episode contains all the required locations (can be done before processing)
        if All(requiredLocations, function(rl) return Any(episode.Regions, function(region) return region.name:lower():find(rl:lower()) and true or false end)  end) then
            episode:Initialize(self.Actor, true)
            if DEBUG then
                print '---------------------------------------------started processing regions----------------------------------------'
            end
            episode:ProcessRegions()
            if DEBUG then
                print '---------------------------------------------finished processing regions----------------------------------------'
            end
            --now I have for all POI and objects the location set
            local objectMap = {}
            local reverseObjectMap = {}
            print('Required objects nr '..#requiredObjects)
            if All(requiredObjects, function(ro) 
                print(ro.name or 'NULL REQUIRED OBJECT NAME!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
                local r = FirstOrDefault(episode.Objects, function(o) 
                    print(o.type:lower()..' vs '..ro.name:lower())
                    return 
                    not objectMap[o.ObjectId] and o.type:lower() == ro.name:lower() and 
                    (o and o.Region and o.Region.name and o.Region.name:lower():find(ro.location:lower()) and true or false)
                end)
                if r then
                    objectMap[r.ObjectId] = ro.id
                    if DEBUG then
                        print('!!!!!!!!!!!!!!!!!!!!!!Mapped '..r.ObjectId..' to '..ro.id)
                    end
                    reverseObjectMap[ro.id] = r.ObjectId
                else
                    print('!!!!!!!!!!!!!!!!!!!!!!Not mapped '..ro.id)
                end
                r = r or Any(self.SpawnableObjects, function(o) return o:lower() == ro.name:lower() end)
                if r then
                    reverseObjectMap[ro.id] = 'spawnable'
                end
                if not r and DEBUG then
                    print('Episode '..episode.name..' was discarded because the object '..ro.name..' does not exist in region '..ro.location..' or at all')
                end
                return r
            end) then
                if All(requiredActions, function(ra) 
                    local res = Any(self.Interactions, function(a) return a:lower() == ra.name:lower() end) or Any(episode.POI, function(poi) 
                        if DEBUG then
                            if poi.Region then
                                print('***'..poi.Region.name..'')
                            else
                                print('***!!'..poi.Description..' does not have a region')
                            end
                        end
                        return 
                            poi.Region and
                            Any(poi.allActions, function(a) 
                                if DEBUG then
                                    print('**********'..a.Name)
                                    if a.TargetItem and a.TargetItem.ObjectId then
                                        print('**********->'..a.TargetItem.ObjectId)
                                    end
                                end
                                return a.Name:lower() == ra.name:lower() and (ra.name == 'Move' or a.TargetItem.ObjectId and objectMap[a.TargetItem.ObjectId])
                            end) 
                            and (poi.Region.name:lower():find(ra.location:lower()) and true or false )
                        end)  

                    if not res and DEBUG then
                        print('Episode '..episode.name..' was discarded because the action '..ra.name..' with target '..(ra.target or '')..' does not exist in region '..ra.location..' or at all')
                    end

                    return res
                end) then
                    if DEBUG then
                        print('Episode '..episode.name..' is valid')
                    end
                    --episode is valid
                    table.insert(validEpisodes, episode)      
                end        
            end
        end
        episode:Destroy()
    end

    for i,episode_name in ipairs(self.DynamicEpisodes) do
        print(episode_name)
        local episode = DynamicEpisode(episode_name)
        local success = episode:LoadFromFile()

        table.insert(self.AllEpisodes, episode)
    end
    print('---------------------------------------------finished GetValidEpisodes: '..#validEpisodes..' found----------------------------------------')
--find all episodes which contain all the required locations
--and all the required actions
    return Where(self.AllEpisodes, function(e) return Any(validEpisodes, function(ve) return ve.name == e.name end) end)
end

function GraphStory:Play()
    if DEBUG then
        print("GraphStory: Loading dynamic episodes..")
    end

--choose a random valid episode
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    self.Episodes = self:GetValidEpisodes()
    if (not self.Episodes or #self.Episodes == 0) then
        -- error("We could not find any valid episodes")
        outputConsole("We could not find any valid episodes")
        terminatePlayer(self.Actor, "We could not find any valid episodes")
        return
    end


    local worldObjects = Element.getAllByType('object')
    for i, o in ipairs(worldObjects) do
        o.collisions = false
    end

    if DEBUG then
        print("GraphStory:Play Required actors:")
    end 
    --Get the required actors attributes
    local requiredActors = Select(Where(self.graph, function(event)
        return event.Action == 'Exists' and (event.Properties.Gender or event.Properties.Type and event.Properties.Type == 'Actor')
    end), function(event)
        if DEBUG then
            print(event.Properties.Name..' gender: '..event.Properties.Gender)
        end
        event.Properties.id = event.id
        return event
    end)
    if not requiredActors or #requiredActors == 0 then
        error('No actors provided in the input graph. Make sure the format is the one required: ex: {"Action": "Exists", "id": ..., "Actor":{"id":...,"Gender":...,"Name":...}}')
    end

    if DEBUG then
        print("GraphStory: Picking a valid skin for the first actor...")
    end 

    local skin = PickRandom(Where(SetPlayerSkin.PlayerSkins, function(s)
        return not s.isTaken and requiredActors[1].Properties.Gender == s.Gender 
    end))
    if skin then
        skin.TargetItem = self.Actor
        skin.Performer = self.Actor
        skin:Apply(requiredActors[1].Properties)

        if not CURRENT_STORY.History[self.Actor:getData('id')] then
            CURRENT_STORY.History[self.Actor:getData('id')] = {}
        end

        if not SCREENSHOTS[self.Actor:getData('id')] then
            SCREENSHOTS[self.Actor:getData('id')] = {}
        end
        if not SCREENSHOTS[self.Actor:getData('id')][self.Id] then
            SCREENSHOTS[self.Actor:getData('id')][self.Id] = 0
        end

        self.StartTime = os.time()
        if self.LogData then
            self.Actor:setData('takenShots', 0)
            self.RecorderTimer = Timer(
                function (playerId, storyId)
                    local story = CURRENT_STORY
                    local player = story.Actor
    
                    if not story.Disposed then
                        if player:getData('takenShots') then
                            player:setData('takenShots', 1 + player:getData('takenShots'))
                        else
                            player:setData('takenShots', 1)
                        end
                        player:takeScreenShot(960, 540, playerId..';'..player:getData('storyId')..';'..player.name, 50)
                    else
                        local requestedShots = player:getData('takenShots')
                        local actuallyTaken = SCREENSHOTS[player:getData('id')][story.Id]
    
                        if DEBUG then
                            outputConsole("RecorderTimer - waiting to download all the screenshots: " .. actuallyTaken .. " / " .. requestedShots)
                        end
    
                        if actuallyTaken >= requestedShots then
                            if DEBUG then
                                outputConsole("RecorderTimer - DONE")
                            end
                            story.RecorderTimer:destroy()
                            terminatePlayer(player, "story ended")
                        end
                    end
                end
            , LOG_FREQUENCY, 0, self.Actor:getData('id'), self.Id)
        end

        if DEBUG then
            print("GraphStory: Loading a random valid episode from "..#self.Episodes.."...")
        end
        math.randomseed(os.clock()*100000000000)
        math.random(); math.random(); math.random()
        self.CurrentEpisode = PickRandom(self.Episodes)
        print(self.CurrentEpisode.name)
        self.CurrentEpisode:Initialize(self.Actor, false, requiredActors, self.graph)
        
        self.Actor:setData('pickedObjects', {})

        if DEBUG then
            print("GraphStory:Play - chosen valid skin and episode. Playing episode")
        end
        self.CurrentEpisode:ProcessRegions()
        self:ProcessActions(requiredActors)

        self.CurrentEpisode:Play(self.Actor, self.graph)
    else
        error("GraphStory:Play could not find a valid skin for the main player with gender "..requiredActors[1].Properties.Gender)
    end
end

--Not used
function GraphStory:FindLocationAndActionForEvent(event)
    local inventoryItems = {}
    if self.Actor:getData('inventory') then
        local length = tonumber(self.Actor:getData('inventory'))
        for i = 1,length do
            table.insert(inventoryItems, self.Actor:getData('inventory_'..i))
        end
    end
    local firstLocation = PickRandom(Where(episode.POI, function(poi) 
        return
            (poi.Region and not event.Location or poi.Region.name:lower():find(event.Location[1]:lower()) and true or false) --the location name is the one specified in the first event
            and 
            (
                Any(poi.allActions, function(action) return action.Name:lower() == event.Action:lower() end) --the location contains an action defined in the first event
                or
                --the action is with an inventory item => create by hand the action
                Any(inventoryItems, function(item) return #event.Entities > 1 and item:lower() == self.graph[event.Entities[2]].Properties.Name:lower() end)
            )
        end))
end

function GraphStory:ProcessActions(graphActors)
    print("GraphStory:ProcessActions --------------------------------------------------")
    local episode = self.CurrentEpisode

    local requiredObjects = Select(Where(self.graph, function(event)
        return event.Action == 'Exists' and not event.Properties.Gender
    end), function(event)
        local location = ''
        if event.Location and #event.Location > 0 then location = event.Location[1] end
        return { location = location, name = event.Properties.Name, id = event.id }
    end)
    local objectMap = {}
    local reverseObjectMap = {}
    local interactionPoiMap = {}
    local interactionProcessedMap = {}
    All(requiredObjects, function(ro) 
        local r = FirstOrDefault(episode.Objects, function(o) return not objectMap[o.ObjectId] and o.type:lower() == ro.name:lower() and (o.Region.name:lower():find(ro.location:lower()) and true or false) end)
        if r then
            objectMap[r.ObjectId] = ro.id
            if DEBUG then
                print('ProcessActions!!!!!!!!!!!!!!!!!!!!!!Mapped '..r.ObjectId..' to '..ro.id)
            end
            reverseObjectMap[ro.id] = r.ObjectId
        else
            print('ProcessActions!!!!!!!!!!!!!!!!!!!!!!Not mapped '..ro.id)
            
        end
        r = r or Any(self.SpawnableObjects, function(o) return o:lower() == ro.name:lower() end)
        if r then
            reverseObjectMap[r] = 'spawnable'
        end
        if not r and DEBUG then
            print('Episode '..episode.name..' was discarded because the object '..ro.name..' does not exist in region '..ro.location..' or at all')
        end
        return r
    end)
    self.reverseObjectMap = reverseObjectMap

    for _,a in ipairs(graphActors) do
        print(a.id)
        self.actionsQueues[a.id] = {}
        --find the first event for the current actor
        local firstEvent = FirstOrDefault(self.graph, function(event)
            return event.id == self.temporal['starting_actions'][a.id]
        end)
        if not firstEvent then
            error('Could not find the first event for actor '..a.id)
        elseif DEBUG then
            print('First event: '..firstEvent.id..' in location '..firstEvent.Location[1]..' with actor '..firstEvent.Entities[1])
        end
        firstEvent.isInteraction = Any(self.Interactions, function(a) return a:lower() == firstEvent.Action:lower() end)
        if firstEvent.isInteraction then
            firstEvent.interactionRelation = FirstOrDefault(self.temporal[firstEvent.id].relations, function(rel) return self.temporal[rel].type == 'starts_with' end)
            firstEvent.interactionEvent = FirstOrDefault(self.graph, function(a) 
                return a.id and self.temporal[a.id] and self.temporal[a.id].relations
                    and Any(self.temporal[a.id].relations, function(rel) return rel == firstEvent.interactionRelation end) end)
        end
        --TODO: define custom logic for actions which doesn't have as target an object
        --if it is an interaction -> the poi has to be the same for both actors...
        local firstLocation = PickRandom(Where(episode.POI, function(poi) 
            return 
                (firstEvent.isInteraction and 
                    (
                        not interactionPoiMap[firstEvent.interactionRelation]
                        or 
                        poi.LocationId == interactionPoiMap[firstEvent.interactionRelation]
                    ) 
                    or not firstEvent.isInteraction and not poi.isBusy
                )
                and
                (poi.Region and poi.Region.name:lower():find(firstEvent.Location[1]:lower()) and true or false) --the location name is the one specified in the first event
                and
                (
                    firstEvent.isInteraction 
                    or 
                    Any(poi.allActions, function(action) 
                        return action.Name:lower() == firstEvent.Action:lower()
                        and (#firstEvent.Entities < 2 or
                        (action.TargetItem.ObjectId and action.TargetItem.type == self.graph[firstEvent.Entities[2]].Properties.Name --action has as target an object of type x
                        and action.TargetItem.ObjectId == reverseObjectMap[firstEvent.Entities[2]])) --the instance of the object is the one required
                    end)
                )
                --the location contains an action defined in the first event
        end))
        if not firstLocation then
            error('Could not find the first location '..firstEvent.Location[1])
        end

        print('Actor '..a.id..' will be spawned in the location '..firstLocation.Description)

        --this is the first location -> the place where the actor or ped is first spawned
        if a.id == self.Actor:getData('id') then
            episode.StartingLocation = firstLocation
            firstLocation.isBusy = true
            --set the interaction to take place in the location found for the first player
            if firstEvent.isInteraction then
                interactionPoiMap[firstEvent.interactionRelation] = firstLocation.LocationId
            end
        else
            --this is ped logic (not the main player)
            firstLocation.isBusy = true
            local ped = FirstOrDefault(self.CurrentEpisode.peds, function(p) return p:getData('id') == a.id end)
            ped:setData('startingPoiIdx', LastIndexOf(episode.POI, firstLocation))
            ped.interior = firstLocation.Interior
            if firstEvent.isInteraction then
                if interactionPoiMap[firstEvent.interactionRelation] == firstLocation.LocationId then
                    --only the second player reaches this code
                    ped.position = firstLocation.position + Vector3(-0.7,-0.7,0)
                else
                    --only the first player reaches this code
                    ped.position =  firstLocation.position
                end
                interactionPoiMap[firstEvent.interactionRelation] = firstLocation.LocationId
            else
                ped.position = firstLocation.position
                ped.rotation = Vector3(0,0,firstLocation.Angle)    
            end
        --else
            --this is a ped => it's starting location id is set in StoryEpisodeBase.Initialize()
        end
        self.interactionPoiMap = interactionPoiMap
        self.interactionProcessedMap = interactionProcessedMap
        self.lastEvents[a.id] = firstEvent
        self.lastLocations[a.id] = firstLocation
    end
    print("GraphStory:ProcessActions --------------------------------------------------")
end

function GraphStory:End()
    if DEBUG then
        outputConsole("GraphStory:End")
    end

    self.CurrentEpisode:Destroy()
    self.Disposed = true
end