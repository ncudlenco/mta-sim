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
    o.MaxActions = 9999
    o.actionsQueues = {}
    if not o.Actor then
        outputConsole("Error: Actor is null "..o.Id)
    end
    o.Actor:setData('storyId', o.Id)
    o.graph = nil
    local file = fileOpen(INPUT_FOLDER..LOAD_FROM_GRAPH)
    if file then
        local jsonStr = fileRead(file, fileGetSize(file))
        o.graph = fromJSON(jsonStr)
        fileClose(file)
        
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
    local requiredLocations = UniqueStr(Select(Where(self.graph, function(event)
        return event.Location or (event.Target and event.Target.Location)
    end), function(event)
        return event.Location or event.Target.Location
    end))
    if DEBUG then
        for _,v in pairs(requiredLocations) do
            print(v)
        end
    end
--a list of all the objects and their locations (temporary objects i.e. cigarette should not be checked )
    local requiredObjects = Select(Where(self.graph, function(event)
        return event.Action == 'Exists' and event.Target and event.Target.Location
    end), function(event)
        return { location = event.Target.Location, name = event.Target.Name }
    end)
    --a list of all the actions and their locations (a POI is placed in a location, in a POI I have allActions)
    local requiredActions = Select(Where(self.graph, function(event)
        return event.Action ~= 'Exists'
    end), function(event)
        return { location = event.Location, name = event.Action }
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
            if All(requiredObjects, function(ro) 
                local r = Any(episode.Objects, function(o) return o.type:lower() == ro.name:lower() and (o.Region.name:lower():find(ro.location:lower()) and true or false) end)  
                r = r or Any(self.SpawnableObjects, function(o) return o:lower() == ro.name:lower() end)
                if not r and DEBUG then
                    print('Episode '..episode.name..' was discarded because the object '..ro.name..' does not exist in region '..ro.location..' or at all')
                end
                return r
            end) then
                if All(requiredActions, function(ra) 
                    local res = Any(episode.POI, function(poi) 
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
                                    print('**********'..a.Name..'')
                                end
                                return a.Name:lower() == ra.name:lower() 
                            end) 
                            and (poi.Region.name:lower():find(ra.location:lower()) and true or false )
                        end)  

                    if not res and DEBUG then
                        print('Episode '..episode.name..' was discarded because the action '..ra.name..' does not exist in region '..ra.location..' or at all')
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
    math.randomseed(os.time())
    math.random(); math.random(); math.random()
    math.randomseed(os.time())
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
        return event.Action == 'Exists' and event.Actor
    end), function(event)
        if DEBUG then
            print(event.Actor.Name..' gender: '..event.Actor.Gender)
        end 
        return event.Actor
    end)
    if not requiredActors or #requiredActors == 0 then
        error('No actors provided in the input graph. Make sure the format is the one required: ex: {"Action": "Exists", "id": ..., "Actor":{"id":...,"Gender":...,"Name":...}}')
    end

    if DEBUG then
        print("GraphStory: Picking a valid skin for the first actor...")
    end 

    local skin = PickRandom(Where(SetPlayerSkin.PlayerSkins, function(s)
        return not s.isTaken and requiredActors[1].Gender == s.Gender 
    end))
    if skin then
        skin.TargetItem = self.Actor
        skin.Performer = self.Actor
        skin:Apply(requiredActors[1])

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
            print("GraphStory: Loading a random valid episode...")
        end
        math.randomseed(os.time())
        math.random(); math.random(); math.random()
        self.CurrentEpisode = PickRandom(self.Episodes)
        print(self.CurrentEpisode.name)
        --replace pickrandom location for players
        --replace random action choosing for players
        self.CurrentEpisode:Initialize(self.Actor, false, requiredActors, self.graph)
        
        self.Actor:setData('pickedObjects', {})

        if DEBUG then
            print("GraphStory:Play - chosen valid skin and episode. Playing episode")
        end
        self.CurrentEpisode:ProcessRegions()
        self:ProcessActions(requiredActors)

        self.CurrentEpisode:Play(self.Actor, self.graph)
    else
        error("GraphStory:Play could not find a valid skin for the main player with gender "..requiredActors[1].Gender)
    end
end

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
            (poi.Region and poi.Region.name:lower():find(event.Location:lower()) and true or false) --the location name is the one specified in the first event
            and 
            (
                Any(poi.allActions, function(action) return action.Name:lower() == event.Action:lower() end) --the location contains an action defined in the first event
                or
                --the action is with an inventory item => create by hand the action
                Any(inventoryItems, function(item) return item:lower() == event.Target.Name:lower() end)
            )
        end))
end

function GraphStory:ProcessActions(graphActors)
    print("GraphStory:ProcessActions --------------------------------------------------")

    local episode = self.CurrentEpisode
    for _,a in ipairs(graphActors) do
        print(a.id)
        self.actionsQueues[a.id] = {}
        --find the first event for the current actor
        local firstEvent = FirstOrDefault(CURRENT_STORY.graph, function(event)
            return event.Actor and event.Actor.id == a.id and event.Action ~= 'Exists' and All(Where(CURRENT_STORY.graph, 
                function(evt) 
                    return evt.id ~= event.id and evt.Actor and event.Action ~= 'Exists' and evt.Actor.id == event.Actor.id
                end), function(evt)
                return evt.Next ~= event.id
            end)
        end)
        if not firstEvent then
            error('Could not find the first event for actor '..a.id)
        elseif DEBUG then
            print('First event: '..firstEvent.id..' in location '..firstEvent.Location..' with actor '..firstEvent.Actor.id)
        end
        local firstLocation = FirstOrDefault(episode.POI, function(poi) 
            return (poi.Region and poi.Region.name:lower():find(firstEvent.Location:lower()) and true or false) --the location name is the one specified in the first event
                and Any(poi.allActions, function(action) return action.Name:lower() == firstEvent.Action:lower() end) --the location contains an action defined in the first event
        end)
        if not firstLocation then
            error('Could not find the first location '..firstEvent.Location)
        end

        print('Location found'..firstLocation.Description)

        if a.id == self.Actor:getData('id') then
            episode.StartingLocation = firstLocation
        else
            --this is a ped => it's starting location id is set in StoryEpisodeBase.Initialize()
        end

        local event = firstEvent
        local location = firstLocation
        while (event) do
            print(event.id)
            --if the event action has prerequisites then add them first if they are not already in the queue
            local eventAction = FirstOrDefault(location.allActions, function(action) return action.Name:lower() == event.Action:lower() end)
            if not eventAction then
                error('Event action could not be found '..event.Action)
            end
            local actionsChain = {}
            local mandatoryPrevAction = eventAction
            local guard = 0
            while(mandatoryPrevAction and guard < 10) do
                print('Mandatory action:'.. mandatoryPrevAction.Name)

                mandatoryPrevAction = FirstOrDefault(location.allActions, function(action)
                    print('Evaluating as prev action '.. action.ActionId .. ': '..action.Name) 
                    if (action.NextAction and not isArray(action.NextAction)) then
                        print('Next action '.. action.NextAction.ActionId .. ': '..action.NextAction.Name) 
                    end
                    return mandatoryPrevAction ~= action and action.Name ~= 'Move' and
                        action.NextAction and ((isArray(action.NextAction) and Any(action.NextAction, function(na) 
                        return na == mandatoryPrevAction 
                    end)) 
                    or (not isArray(action.NextAction) and action.NextAction == mandatoryPrevAction ))
                end)
                if mandatoryPrevAction then
                    print('Mandatory prev action:'.. mandatoryPrevAction.Name)
                    table.insert(actionsChain, 1, mandatoryPrevAction)
                end
                guard = guard + 1
            end
            if guard >= 10 then
                error('Infinite loop mandatoryPrevAction')
            end
            print(eventAction.Name)
            table.insert(actionsChain, eventAction)
--looking backward in the graph's chain of events to see if any actions were already processed is not necessary because
--in the steps below, we make sure that when we reach the first action from an enforced chain, then we process all their previous and following mandatory actions
            local nextEvent = FirstOrDefault(self.graph, function(evt) return evt.id == event.Next end)
            local nextMandatoryAction = eventAction.NextAction
            while (nextMandatoryAction) do
                --if the action has mandatory closing actions then add them if they are not already in the graph next actions
                if  nextEvent 
                    and (isArray(nextMandatoryAction)
                    and Any(nextMandatoryAction, function(action) 
                        return action.Name:lower() == nextEvent.Action:lower()--action.location is the same as the event.next.location (technically, in a chain the location doesn't change, except when it does (Dance)...)
                    end)
                    or (not isArray(nextMandatoryAction) and nextMandatoryAction.Name:lower() == nextEvent.Action:lower())
                    )
                    and
                    (eventAction.NextLocation.Region.name:lower():find(nextEvent.Location:lower()) and true or false)
                then
                    if isArray(nextMandatoryAction) then
                        nextMandatoryAction = FirstOrDefault(nextMandatoryAction, function(action) return action.Name:lower() == nextEvent.Action:lower() end)
                    end
                    --if the action is set in the next future event in the same location, skip the processing of the next future event
                    nextEvent = FirstOrDefault(self.graph, function(evt) return evt.id == nextEvent.Next end)
                end

                if isArray(nextMandatoryAction) then
                    nextMandatoryAction = PickRandom(nextMandatoryAction)
                end
                print(nextMandatoryAction.Name)
                table.insert(actionsChain, nextMandatoryAction)
                nextMandatoryAction = nextMandatoryAction.NextAction
            end
            --add the required actions

            for _, action in ipairs(actionsChain) do
                table.insert(self.actionsQueues[a.id], action)
            end
            
            --if this is the first event the player will be spawned in the required location
            --otherwise, if the player is not in the required location then add a move action to the required location (select it from allActions of the currentLocation)
            local nextLocation = nil
            if nextEvent then
                nextLocation = FirstOrDefault(episode.POI, function(poi) 
                    return poi.Region and (poi.Region.name:lower():find(nextEvent.Location:lower()) and true or false )
                    and Any(poi.allActions, function(action) return action.Name:lower() == nextEvent.Action:lower() end) 
                end)
            end
            if nextLocation and nextLocation ~= location then
                local moveAction = FirstOrDefault(location.allActions, function(action) return action.Name == 'Move' and action.TargetItem == nextLocation end)
                table.insert(self.actionsQueues[a.id], moveAction)
            end

            event = nextEvent
            location = nextLocation
        end
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