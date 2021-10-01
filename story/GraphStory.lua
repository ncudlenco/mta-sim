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
        outputConsole("Error: Actor is null "..o.Id)
    end
    o.Actor:setData('storyId', o.Id)
    o.graph = nil
    o.temporal = nil
    local file = fileOpen(INPUT_FOLDER..LOAD_FROM_GRAPH)
    if file then
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
        return event.Action == 'Exists' and not event.Actor
    end), function(event)
        return { location = event.Target.Location or '', name = event.Target.Name, id = event.id }
    end)
    --a list of all the actions and their locations (a POI is placed in a location, in a POI I have allActions)
    local requiredActions = Select(Where(self.graph, function(event)
        return event.Action ~= 'Exists'
    end), function(event)
        return { location = event.Location, name = event.Action, target = event.Target.id }
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
                                return a.Name:lower() == ra.name:lower() and a.TargetItem.ObjectId and objectMap[a.TargetItem.ObjectId]
                            end) 
                            and (poi.Region.name:lower():find(ra.location:lower()) and true or false )
                        end)  

                    if not res and DEBUG then
                        print('Episode '..episode.name..' was discarded because the action '..ra.name..' with target '..ra.target..' does not exist in region '..ra.location..' or at all')
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

    local requiredObjects = Select(Where(self.graph, function(event)
        return event.Action == 'Exists' and not event.Actor
    end), function(event)
        return { location = event.Target.Location or '', name = event.Target.Name, id = event.id }
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

    for _,a in ipairs(graphActors) do
        print(a.id)
        self.actionsQueues[a.id] = {}
        --find the first event for the current actor
        local firstEvent = FirstOrDefault(self.graph, function(event)
            return event.id == self.temporal['starting_actions'][a.id]
            -- event.Actor and event.Actor.id == a.id and event.Action ~= 'Exists' and All(Where(self.graph, 
            --     function(evt) 
            --         return evt.id ~= event.id and evt.Actor and event.Action ~= 'Exists' and evt.Actor.id == event.Actor.id
            --     end), function(evt)
            --     return evt.Next ~= event.id
            -- end)
        end)
        if not firstEvent then
            error('Could not find the first event for actor '..a.id)
        elseif DEBUG then
            print('First event: '..firstEvent.id..' in location '..firstEvent.Location..' with actor '..firstEvent.Actor.id)
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
        local firstLocation = FirstOrDefault(episode.POI, function(poi) 
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
                (poi.Region and poi.Region.name:lower():find(firstEvent.Location:lower()) and true or false) --the location name is the one specified in the first event
                and
                (
                    firstEvent.isInteraction 
                    or 
                    Any(poi.allActions, function(action) 
                        return action.Name:lower() == firstEvent.Action:lower() 
                        and action.TargetItem.ObjectId and action.TargetItem.type == self.graph[firstEvent.Target.id].Target.Name --action has as target an object of type x
                        and action.TargetItem.ObjectId == reverseObjectMap[firstEvent.Target.id] --the instance of the object is the one required
                    end)
                )
                --the location contains an action defined in the first event
        end)
        if not firstLocation then
            error('Could not find the first location '..firstEvent.Location)
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

        local event = firstEvent
        local location = firstLocation
        while (event) do
            print(event.id)
            --if the event action has prerequisites then add them first if they are not already in the queue
            local eventAction = nil
            local actionsChain = {}

            if event.isInteraction then
                --set the actors one in front of the other in the same location...
                --create the interaction actions / locations
                local ped1 = FirstOrDefault(self.CurrentEpisode.peds, function(p) return p:getData('id') == a.id end) or self.Actor
                local ped2 = FirstOrDefault(self.CurrentEpisode.peds, function(p) return p:getData('id') == event.interactionEvent.Actor.id end) or self.Actor

                --The interaction action will be executed only from the first actor
                if interactionProcessedMap[event.interactionRelation] then
                    local wait = Wait { performer = ped1, nextLocation = location, targetItem = ped2, graphId = self.CurrentEpisode.graphId, doNothing=true, time=10000000 }
                    eventAction = wait
                else
                    local wait = Wait { performer = ped1, nextLocation = location, targetItem = ped2, graphId = self.CurrentEpisode.graphId, doNothing=false, time=10000000 }
                    table.insert(actionsChain, wait)
                    if event.Action == 'HandShake' then
                        eventAction = HandShake {performer = ped1, nextLocation = location, targetPlayer = ped2, targetItem = ped2, time = random(6000, 15000)}
                    elseif event.Action == 'Kiss' then
                        eventAction = Kiss { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = ped2 }
                    elseif event.Action == 'Hug' then
                        eventAction = Hug { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = ped2 }
                    elseif event.Action == 'Laugh' then
                        local jokeTarget = PickRandom({ped1, ped2})
                        eventAction = Laugh { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = jokeTarget }
                    elseif event.Action == 'Talk' then
                        eventAction = Talk { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = ped2 }
                    else
                        error('Interaction '..event.Action..' not implemented')
                    end

                    if not eventAction then
                        error('Event action could not be instantiated. '..event.Action)
                    end
                    wait.NextAction = eventAction
                end
                interactionProcessedMap[event.interactionRelation] = true
            else
                eventAction = FirstOrDefault(location.allActions, function(action) return action.Name:lower() == event.Action:lower() end)
                if not eventAction then
                    error('Event action could not be found '..event.Action)
                end
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
                nextEvent.isInteraction = Any(self.Interactions, function(a) return a:lower() == nextEvent.Action:lower() end)
                if nextEvent.isInteraction then
                    nextEvent.interactionRelation = FirstOrDefault(self.temporal[nextEvent.id].relations, function(rel) return self.temporal[rel].type == 'starts_with' end)
                    nextEvent.interactionEvent = FirstOrDefault(self.graph, function(a) 
                        return a.id and self.temporal[a.id] and self.temporal[a.id].relations
                            and Any(self.temporal[a.id].relations, function(rel) return rel == nextEvent.interactionRelation end) end)
                end
                local strIsInteraction = 'false'
                if nextEvent.isInteraction then
                    strIsInteraction = 'true'
                end
                print('Next event: '..nextEvent.id..' isInteraction '..strIsInteraction)

                nextLocation = FirstOrDefault(episode.POI, function(poi) 
                    return 
                    (nextEvent.isInteraction and 
                        (
                            not interactionPoiMap[nextEvent.interactionRelation]
                            or 
                            poi.LocationId == interactionPoiMap[nextEvent.interactionRelation]
                        )
                        or not nextEvent.isInteraction
                    )
                    and
                    poi.Region and (poi.Region.name:lower():find(nextEvent.Location:lower()) and true or false )
                    and 
                    (
                        nextEvent.isInteraction 
                        or 
                        Any(poi.allActions, function(action) 
                            return action.Name:lower() == nextEvent.Action:lower() --the location contains the required action for the next event
                            and action.TargetItem.ObjectId and action.TargetItem.type == self.graph[nextEvent.Target.id].Target.Name --action has a target an object of type x
                            and action.TargetItem.ObjectId == reverseObjectMap[nextEvent.Target.id]
                        end) 
                    )
                end)
                if not nextLocation then
                    error('Could not find the next location '..nextEvent.id..': '..nextEvent.Location)
                elseif nextEvent.isInteraction then
                    if interactionPoiMap[nextEvent.interactionRelation] == nextLocation.LocationId then
                        --only subsequent actors reach this section (i.e. after a location was chosen for the interaction)
                        local clone = Location(nextLocation.X - 0.7, nextLocation.Y - 0.7, nextLocation.Z, nextLocation.Angle, nextLocation.Interior, nextLocation.Description, nextLocation.Region, false)
                         --Î(this is an upward arrow) TODO: is it good, is it bad?
                        clone.LocationId = nextLocation.LocationId
                        clone.allActions = nextLocation.allActions --should include move actions here...
                        nextLocation = clone
                    end
                    interactionPoiMap[nextEvent.interactionRelation] = nextLocation.LocationId
                end

                print('Next location '..nextLocation.Description)
            end
            if nextLocation and nextLocation ~= location then
                --if this is an interaction then create a move action with target the other player. handle internally inside the move action the positioning of the two players
                --
                print('Next action is in another location. Inserting a Move action from '..location.Description..' to '..nextLocation.Description)
                local moveAction = FirstOrDefault(location.allActions, function(action) return action.Name == 'Move' and action.TargetItem == nextLocation end)
                --actually I need to clone the move action to point to different coordinates inside the next location
                local clone = Move{performer = moveAction.Performer, targetItem = nextLocation, nextLocation = nextLocation, prerequisites = moveAction.Prerequisites, graphId = moveAction.graphId}
                clone.TargetItem = nextLocation
                table.insert(self.actionsQueues[a.id], clone)
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