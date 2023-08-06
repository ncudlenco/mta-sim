GraphStory = class(StoryBase, function(o, spectators, logData)
    StoryBase.init(o, spectators, maxActions)
    o.LogData = logData
    o.AllEpisodes = {
        -- House1(),
        -- House3(),
        -- House8(),
        -- House10(),
        -- House12()
    }
    o.Episodes = {
        -- House1(),
        -- House3(),
        -- House8(),
        -- House10(),
        -- House12()
    }
    o.DynamicEpisodes = {
      "house1_sweet",
      "house1_preloaded",
    --   "house3_preloaded", --NOT WORKING! The pathfinding seems flawed here, when we have 2 levels?
    --   "house7", --NOT WORKING! Potential issue when the link POI is located outside a region
      "house8_preloaded",
      "house9",
    --   "house10_preloaded", -- Not Working!
      "house12_preloaded", -- Working but needs the objects removed. Some flakiness exists but in general it works...
      "garden",
      "office",
      "office2",
      "common",
      "gym1",
      "gym2",
      "gym3"
    }
    o.Disposed = false
    o.SpawnableObjects = {
        "Cigarette",
        "MobilePhone",
        -- "Drinks",
        -- "Food"
    }
    o.Interactions = {
        "Handshake",
        "Talk",
        "Kiss",
        "Hug",
        "Laugh",
        "Give",
        "INV-Give",
        "Receive"
    }
    o.MiddleActions = {
        "Drink",
        "Smoke",
        "TalkPhone",
        "Eat"
    }
    o.MaxActions = 9999
    o.actionsQueues = {}
    for _,spectator in ipairs(o.Spectators) do
        if #o.Spectators < 1 or not spectator then
            outputConsole("Error: Not enough spectators registered for story "..o.Id)
        end
        spectator:setData('storyId', o.Id)
    end
    o.graph = nil
    o.temporal = nil
    o.lastEvents = {}
    o.lastLocations = {}
    o.validMemo = {}
    print(LOAD_FROM_GRAPH)
    local file = fileOpen(LOAD_FROM_GRAPH)
    if file then
        o.Loggers = Select(spectators, function(spectator) return Logger(LOAD_FROM_GRAPH..'_out/'..o.Id..'/'..spectator:getData('id'), true, o, spectator) end)

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
    else
        print("WARNING: The file "..LOAD_FROM_GRAPH.." could not be opened!")
    end

    CURRENT_STORY = o
end)

function GraphStory:ExploreValidEpisodeLinks(
    episode,
    requiredLocations,
    requiredObjects,
    requiredActions,
    currentSubset
)
    --assume current episode is already valid (i.e it won't choose a location from which it can go back into a different house defined for randomness)
    local unprocessedPoiWithLinks = Where(episode.POI, function(poi) return #poi.episodeLinks > 0 and
        All(currentSubset, function(e) return not Any(poi.episodeLinks, function(l) return l == e.name end) end)
    end)
    local linkedEpisodes = reduce(Select(unprocessedPoiWithLinks,
        function(poi) return
            Select(poi.episodeLinks,
                function(eLink) return
                    FirstOrDefault(self.Episodes, function(e) return e.name == eLink end)
                end
            )
        end
    ), {}, concat)
    return self:ExploreValidEpisodesSubset(linkedEpisodes, requiredLocations, requiredObjects, requiredActions, currentSubset)
end

function GraphStory:ExploreValidEpisodesSubset(
    episodes,
    requiredLocations,
    requiredObjects,
    requiredActions,
    currentSubset
)
    if DEBUG_VALIDATION then
        print('Exploring '..join(';', Select(episodes, function(e) return e.name end)))
        print('Required locations '..join(';', requiredLocations))
        print('Required objects '..join(';', Select(requiredObjects, function(e) return e.name end)))
        print('Required actions '..join(';', Select(requiredActions, function(e) return e.name..' - '..e.location..' -> '..(e.target or '') end)))
    end
    if (#requiredLocations + #requiredObjects + #requiredActions) == 0 then
        return currentSubset
    elseif #episodes == 0 then
        return {} --If I still have requirements by I don't have episodes left to evaluate then there's no valid episode subset
    else
        local unexploredBucket = concat(episodes, {})
        while (#unexploredBucket > 0) do
            local maxCoverData = self:GetMaxCoveringEpisode(unexploredBucket, requiredLocations, requiredObjects, requiredActions, currentSubset)
            if maxCoverData and maxCoverData.maxScore and maxCoverData.episode then
                if DEBUG_VALIDATION then
                    print('Max covering episode is '..maxCoverData.episode.name..' with a score of '..maxCoverData.maxScore.setCoverScore)
                end
                local validSubset = self:ExploreValidEpisodeLinks(
                    maxCoverData.episode,
                    maxCoverData.maxScore.requiredLocations,
                    maxCoverData.maxScore.requiredObjects,
                    maxCoverData.maxScore.requiredActions,
                    concat(currentSubset, {maxCoverData.episode})
                )
                if #validSubset > 0 then
                    return validSubset
                else
                    unexploredBucket = Where(unexploredBucket, function(e) return e ~= maxCoverData.episode end)
                end
            else
                return {}  --If I still have requirements and episodes but there's no further valid episode => there's no valid episode subset
            end
        end
    end
    return {} --Couldn't find anything
end

function GraphStory:GetMaxCoveringEpisode(
    episodes,
    requiredLocations,
    requiredObjects,
    requiredActions,
    currentSubset
)
if DEBUG_VALIDATION then
    print('GetMaxCoveringEpisode from '..join(';', Select(episodes, function(e) return e.name end)))
    print('Required locations '..join(';', requiredLocations))
    print('Required objects '..join(';', Select(requiredObjects, function(e) return e.name end)))
    print('Required actions '..join(';', Select(requiredActions, function(e) return e.name..' - '..e.location..' -> '..(e.target or '') end)))
end
    --Greedy select the episode covering the max nr of requirements
    local maxScore = nil
    local maxScoreEpisodes = {}
    for i,episode in ipairs(episodes) do
        local score = self:ValidateEpisode(episode, requiredLocations, requiredObjects, requiredActions)
        if maxScore == nil or score.setCoverScore >= maxScore.setCoverScore then
            if maxScore == nil or maxScore.setCoverScore ~= score.setCoverScore then
                maxScoreEpisodes = {episode}
            else
                table.insert(maxScoreEpisodes, episode)
            end
            maxScore = score
        end
    end

    if maxScore.setCoverScore > 0 then
        return {maxScore = maxScore, episode = PickRandom(maxScoreEpisodes)}
    else
        return nil
    end
end

function GraphStory:ValidateEpisode(
    episode,
    requiredLocations,
    requiredObjects,
    requiredActions
)
    -- if self.validMemo[episode.name] then --The memo id is not correct because the requirements list changes over time
    --     return self.validMemo[episode.name]
    -- end

    if DEBUG_VALIDATION then
        print('ValidateEpisode '..episode.name)
        print('Required locations '..join(';', requiredLocations))
        print('Required objects '..join(';', Select(requiredObjects, function(e) return e.name end)))
        print('Required actions '..join(';', Select(requiredActions, function(e) return e.name..' - '..e.location..' -> '..(e.target or '') end)))
    end

    local validLocations = Where(requiredLocations, function(rl)
        return Any(episode.Regions, function(region) return region.name:lower():find(rl:lower()) and true or false end)
    end)
    print('validLocations locations '..join(';', validLocations))

    local validObjects = {}
    local validActions = {}
    local setCoverScore = 0
    local res = nil

    -- if Any(validLocations) or #requiredLocations == 0 then
        if not episode.initialized and true or false then
            episode:Initialize(true)
        end
        if DEBUG_VALIDATION then
            print '---------------------------------------------started processing regions----------------------------------------'
        end
        if not episode.processedRegions and true or false then
            episode:ProcessRegions()
        end
        if DEBUG_VALIDATION then
            print '---------------------------------------------finished processing regions----------------------------------------'
        end
        --now I have for all POI and objects the location set
        local actionMap = {}
        local eventMap = {}
        local objectMap = {}
        local eventObjectMap = {}
        local poiMap = {}
        if DEBUG_VALIDATION then
            print('Required objects nr '..#requiredObjects)
        end
        self:MapObjectsActionsAndPoi(requiredObjects, episode, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
        for key, value in pairs(objectMap) do
            if DEBUG_VALIDATION then
                print('!!!!!!!!!!!!!!!!!!!!!!Mapped '..key..' to '..value)
            end
            table.insert(validObjects, {id = value})
        end

        for key, value in pairs(eventMap) do
            if DEBUG_VALIDATION then
                print('!!!!!!!!!!!!!!!!!!!!!!Mapped action '..key..' to '..value)
            end
            table.insert(validActions, {id = key, name = self.graph[key].Action, location = self.graph[key].Location})
        end
        local requiredActions = Where(requiredActions, function(ra) return not eventMap[ra.id] end)

        -- validObjects = Where(requiredObjects, function(ro)
        --     print(ro.name or 'WARNING: OBJECT NAME WAS NULL BUT IT IS REQUIRED!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
        --     local r = FirstOrDefault(episode.Objects, function(o)
        --         if DEBUG_VALIDATION then
        --             print(o.type:lower()..' vs '..ro.name:lower())
        --         end
        --         return not objectMap[o.ObjectId] and o.type:lower() == ro.name:lower() and
        --         (o and o.Region and o.Region.name and o.Region.name:lower():find(ro.location:lower()) and true or false)
        --     end)
        --     if r then
        --         objectMap[r.ObjectId] = ro.id
        --         if DEBUG_VALIDATION then
        --             print('!!!!!!!!!!!!!!!!!!!!!!Mapped '..r.ObjectId..' to '..ro.id)
        --         end
        --         eventObjectMap[ro.id] = r.ObjectId
        --     else
        --         if DEBUG_VALIDATION then
        --             print('!!!!!!!!!!!!!!!!!!!!!!Not mapped '..ro.id)
        --         end
        --     end

        --     r = r or Any(self.SpawnableObjects, function(o) return o:lower() == ro.name:lower() end)
        --     if r then
        --         eventObjectMap[ro.id] = 'spawnable'
        --     end
        --     if not r and DEBUG_VALIDATION then
        --         print('Episode '..episode.name..' was discarded because the object '..ro.name..' does not exist in region '..ro.location..' or at all')
        --     end
        --     return r and true or false
        -- end)
        -- if Any(validObjects) or #requiredObjects == 0 then
            Where(requiredActions, function(ra)
                local res = Any(self.Interactions, function(a) return
                    -- a:lower() ~= 'give' and
                    -- a:lower() ~= 'inv-give' and
                        a:lower() == ra.name:lower()
                    end)
                    or Any(self.MiddleActions, function(a) return
                        a:lower() == ra.name:lower()
                    end)
                    or Any(episode.POI, function(poi)
                        if DEBUG_VALIDATION then
                            if poi.Region then
                                print('***'..poi.Region.name..'')
                            else
                                print('***!!'..poi.Description..' does not have a region')
                            end
                        end
                        return
                            poi.Region and
                            Any(poi.allActions, function(a)
                                if DEBUG_VALIDATION then
                                    print('**********'..a.Name)
                                    if a.TargetItem and a.TargetItem.ObjectId then
                                        print('**********->'..a.TargetItem.ObjectId)
                                    elseif a.TargetItem and a.TargetItem.Region then
                                        print('**********->'..a.TargetItem.Region.name)
                                    end
                                end
                                return a.Name:lower() == ra.name:lower() and (ra.name == 'Move' or not a.TargetItem or a.TargetItem and a.TargetItem.ObjectId and objectMap[a.TargetItem.ObjectId])
                            end)
                            and (poi.Region.name:lower():find(ra.location:lower()) and true or false )
                    end)

                if not res and DEBUG_VALIDATION then
                    print('Episode '..episode.name..' - the action '..ra.name..' with target '..(ra.target or '')..' does not exist in region '..ra.location..' or at all')
                end

                if res then
                    table.insert(validActions, ra)
                end
                return res
            end)
            -- if Any(validActions) or #requiredActions == 0 then
                setCoverScore = #validLocations + #validObjects + #validActions
                if DEBUG_VALIDATION then
                    print('Episode '..episode.name..' validity score is '..setCoverScore)
                end
                --episode is valid
                --remove from current list of constraints the satisfied constraints for the next recursive level
                res = {
                    setCoverScore = setCoverScore,
                    requiredLocations = Where(requiredLocations, function(rl) return not Any(validLocations, function(vl) return vl == rl end) end),
                    requiredObjects = Where(requiredObjects, function(ro) return not Any(validObjects, function(vo) return vo.id == ro.id end) end),
                    requiredActions = Where(requiredActions, function(ra) return not Any(validActions, function(va) return va.name == ra.name and va.location == ra.location end) end)
                }
            -- end
        -- end
    -- end
    if not res then
        res = {
            setCoverScore = setCoverScore,
            requiredLocations = requiredLocations,
            requiredObjects = requiredObjects,
            requiredActions = requiredActions
        }
    end
    self.validMemo[episode.name] = res
    return res
end

function GraphStory:GetValidEpisodes()
    if DEBUG then
        print("GraphStory:GetValidEpisodes: loading all available episodes in memory")--!!!!!!!!!!!!!!!
    end
    for i,episode_name in ipairs(self.DynamicEpisodes) do
        print(episode_name)
        local episode = DynamicEpisode(episode_name)
        local success = episode:LoadFromFile()

        table.insert(self.Episodes, episode)
        table.insert(self.AllEpisodes, episode)
    end

    --first preprocess the graph and extract the requirements:
    --a list of all the locations
    if DEBUG then
        print("GraphStory:GetValidEpisodes: retrieving a list of all the locations in the input graph")
    end
    local requiredLocations = Where(
        UniqueStr(
            Flatten(
                Select(
                    Where(self.graph,
                        function(event)
                            return event.Location ~= nil --converts to bool
                        end
                    ),
                    function(event)
                        return event.Location
                    end
                )
            )
        ),
        function(item)
            return item and item ~= ""
        end
    )
    if DEBUG then
        print("GraphStory:GetValidEpisodes: required locations:")
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
        return { location = location, name = event.Properties.Type, id = event.id }
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

    local validEpisodesSubset = self:ExploreValidEpisodesSubset(self.Episodes, requiredLocations, requiredObjects, requiredActions, {})

    print('---------------------------------------------finished GetValidEpisodes: {'..join(';', Select(validEpisodesSubset, function(e) return e.name end))..'} found----------------------------------------')
--find all episodes which contain all the required locations
--and all the required actions
    return Where(self.AllEpisodes, function(e)
        local isValid = Any(validEpisodesSubset, function(ve) return ve.name == e.name end)
        if not isValid then
            e:Destroy()
        end
        return isValid
    end)
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
        outputConsole("We could not find any valid episodes for the file "..LOAD_FROM_GRAPH)
        for i,spectator in ipairs(self.Spectators) do
            terminatePlayer(spectator, "We could not find any valid episodes for the file "..LOAD_FROM_GRAPH)
        end
        return
    end

    local worldObjects = Element.getAllByType('object')
    for i, o in ipairs(worldObjects) do
        o.collisions = false
    end
    triggerClientEvent ( "onDisablePedCollisions", getRootElement(), true )

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

    if DEBUG then
        print("GraphStory: Loading a random valid episode from "..#self.Episodes.."...")
    end
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    self.CurrentEpisode = MetaEpisode(self.Episodes)
    print(self.CurrentEpisode.name)
    self.CurrentEpisode:Initialize(false, requiredActors, self.graph)

    if DEBUG then
        print("GraphStory:Play - chosen valid skin and episode. Playing episode")
    end
    if self:ProcessActions(requiredActors) then
        self.StartTime = os.time()
        if self.LogData then
            self.RecorderTimer = Timer(
                function ()
                    local story = CURRENT_STORY
                    local elapsedTime = os.time() - self.StartTime
                    print('Elapsed time '..elapsedTime)
                    if elapsedTime > MAX_STORY_TIME then
                        for _,spectator in ipairs(story.Spectators) do
                            EndStory(spectator):Apply()
                        end
                    end

                    for _,spectator in ipairs(story.Spectators) do
                        if not story.Disposed then
                            if spectator:getData('takenShots') then
                                spectator:setData('takenShots', 1 + spectator:getData('takenShots'))
                            else
                                spectator:setData('takenShots', 1)
                            end
                            spectator:takeScreenShot(960, 540, spectator:getData('id')..';'..spectator:getData('storyId')..';'..spectator.name, 50)
                        else
                            local requestedShots = spectator:getData('takenShots')
                            local actuallyTaken = SCREENSHOTS[spectator:getData('id')][spectator:getData('storyId')]

                            if DEBUG then
                                print("RecorderTimer - storyId ".. (spectator:getData('storyId') or "null") .." actorId "..
                                    (spectator:getData('id') or "null") .." waiting to download all the screenshots: " ..
                                    (actuallyTaken or 'null') .. " / " .. (requestedShots or 'null')
                                )
                            end

                            if actuallyTaken >= requestedShots then
                                if DEBUG then
                                    outputConsole("RecorderTimer - DONE")
                                end
                                story.RecorderTimer:destroy()
                                terminatePlayer(spectator, "story ended")
                            end
                        end
                    end
                end
            , LOG_FREQUENCY, 0)
        end
        self.CurrentEpisode:Play(self.graph)
    else
        outputConsole("We could not find any valid episodes for the file "..LOAD_FROM_GRAPH)
        for i,spectator in ipairs(self.Spectators) do
            terminatePlayer(spectator, "We could not find any valid episodes for the file "..LOAD_FROM_GRAPH)
        end
        return
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

function GraphStory:MapObjectsActionsAndPoi(requiredObjects, episode, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
    return All(requiredObjects, function(ro)
        if eventObjectMap[ro.id] then return true end
        if DEBUG_VALIDATION then
            print("The object "..ro.id..':'..ro.name..' is not mapped in any of ')
            for k, v in pairs(eventObjectMap) do
                print(k)
            end
        end

        local eventsWithObjectAsTarget = Where(self.graph, function(g)
            return
                --The action was not already processed
                not actionMap[g.id]
                --The event is of type action
                and g.Action ~= 'Exists'
                --The event is not interaction and is with the required object
                and #g.Entities == 2 and g.Entities[2] == ro.id
                --The event is in the same location as the required object (this will not be valid if the object can move to a different place -- most likely we will not support that)
                and (#g.Location == 0 or g.Location[1] == '' or g.Location[1] == ro.location)
            end
        )

        if DEBUG_VALIDATION then
            for _, e in ipairs(eventsWithObjectAsTarget) do
                print("Event with object "..ro.name..' as target '..e.id)
            end
        end

        local matchingPoiData = PickRandom(DropNull(Select(episode.POI, function(poi)
            local actionMap = {}
            local eventMap = {}
            local objectMap = {}
            local eventObjectMap = {}
            local poiMap = {}

            if DEBUG_VALIDATION then
                print('Assessing actions in poi '..poi.Description)
            end

            -- Starting from the action with the object as target,
            local actionWithMatchingObject = FirstOrDefault(poi.allActions, function(a) return a.TargetItem and a.TargetItem.ObjectId and a.TargetItem.type == ro.name end)
            if not actionWithMatchingObject then
                if DEBUG_VALIDATION then
                    print("Action with matching object does not exist!")
                end
                return nil
            end

            if DEBUG_VALIDATION then
                print("Action with matching object "..actionWithMatchingObject.Name)
            end
            -- find a matching event (same action name and location) then
            local eventMatchingAction = FirstOrDefault(eventsWithObjectAsTarget, function(event)
                return event.Action:lower() == actionWithMatchingObject.Name:lower()
                and (#event.Location == 0 or event.Location == '' or (poi.Region and poi.Region.name:lower():find(event.Location[1]:lower()) and true or false))
            end)

            if not eventMatchingAction then
                if DEBUG_VALIDATION then
                    print("Event matching action does not exist!")
                end
                return nil
            end

            if DEBUG_VALIDATION then
                print('Event matching action '..eventMatchingAction.id)
            end


            local currentAction = actionWithMatchingObject
            local currentEvent = eventMatchingAction
            self:MatchEventAndAction(currentAction, currentEvent, poi, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
            ----verify going back in time if all the actions have matching events (same location, same target objects)
            local previousActionsCandidates = Where(poi.allActions, function(a)
                return
                    (not isArray(a.NextAction) and a.NextAction == currentAction)
                    or (isArray(a.NextAction) and inList(currentAction, a.NextAction))
            end)
            while previousActionsCandidates and #previousActionsCandidates > 0 do
                local previousEventId = FirstOrDefault(self.temporal, function(t) return t.next == currentEvent.id end, true)
                if not previousEventId then
                    if DEBUG_VALIDATION then
                        print("Previous event was null!")
                    end
                    return nil
                else
                    previousEventId = previousEventId.key
                end
                local previousEvent = self.graph[previousEventId]

                if DEBUG_VALIDATION then
                    print('Previous event '..previousEvent.id)
                end

                local previousAction = FirstOrDefault(previousActionsCandidates, function(previousAction)
                    if DEBUG_VALIDATION then
                        print("Previous action "..previousAction.Name)
                    end
                    return self:MatchEventAndAction(previousAction, previousEvent, poi, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
                end)
                if not previousAction then
                    if DEBUG_VALIDATION then
                        print("The event and action can't be matched")
                    end
                    return nil
                else
                    print("Previous action "..previousAction.Name)
                end

                currentAction = previousAction
                previousActionsCandidates = Where(poi.allActions, function(a) return ((not isArray(a.NextAction) or #a.NextAction == 1) and a.NextAction == currentAction) or (isArray(a.NextAction) and inList(currentAction, a.NextAction)) end)
                currentEvent = previousEvent
            end

            ----verify going forward in time if all the actions have matching events
            currentAction = actionWithMatchingObject
            currentEvent = eventMatchingAction
            while currentAction and currentAction.NextAction do
                local nextEventId = self.temporal[currentEvent.id].next
                if not nextEventId then
                    if DEBUG_VALIDATION then
                        print("Next event was null but next action exists!")
                    end
                    return nil
                end
                local nextEvent = self.graph[nextEventId]

                local nextActions = { currentAction.NextAction }
                if isArray(currentAction.NextAction) then
                    nextActions = currentAction.NextAction
                end

                --if multiple possible next actions, choose the first one that matches the next event
                currentAction = FirstOrDefault(nextActions, function(action)
                    return self:MatchEventAndAction(action, nextEvent, poi, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
                end)
                if not currentAction then
                    if DEBUG_VALIDATION then
                        print("There is no next action that matches the next event!")
                    end
                    return nil
                end

                if DEBUG_VALIDATION then
                    print("Next action that also matches next event "..currentAction.Name)
                end
                currentEvent = nextEvent
            end

            if DEBUG_VALIDATION then
                print("This poi is valid, returning ")
            end

            return {
                actionMap = actionMap,
                eventMap = eventMap,
                objectMap = objectMap,
                eventObjectMap = eventObjectMap,
                poiMap = poiMap
            }
        end)))

        if not matchingPoiData and DEBUG then
            print('Episode '..episode.name..' was discarded because the object '..ro.name..' does not exist in region '..ro.location..' or at all or a matching chain of actions could not be found for the object')
        end
        if not matchingPoiData then
            print("Could not find actions required for the object "..ro.name)
            return false
        end

        CopyContents(matchingPoiData.objectMap, objectMap)
        CopyContents(matchingPoiData.eventObjectMap, eventObjectMap)
        CopyContents(matchingPoiData.actionMap, actionMap)
        CopyContents(matchingPoiData.eventMap, eventMap)
        CopyContents(matchingPoiData.poiMap, poiMap)

        return true
    end)
end

function GraphStory:MatchEventAndAction(action, event, poi, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
    if DEBUG_VALIDATION then
        print("Matching action "..action.Name..' against event'..event.id)
    end
    local objectUsedByAction = nil
    if action.TargetItem and action.TargetItem.ObjectId and action.TargetItem.type then
        objectUsedByAction = action.TargetItem
        if DEBUG_VALIDATION then
            print("Action object: "..(objectUsedByAction.type))
        end
    else
        if DEBUG_VALIDATION then
            print("Action object: nil")
        end
    end

    local objectUsedByEvent = nil
    if #event.Entities > 1 and self.graph[event.Entities[2]] and not self.graph[event.Entities[2]].Properties.Gender then
        objectUsedByEvent = self.graph[event.Entities[2]]
        if DEBUG_VALIDATION then
            print("Event object: "..(objectUsedByEvent.Properties.Type))
        end
    else
        if DEBUG_VALIDATION then
            print("Event object: nil")
        end
    end

    --the action name and event actions are equal
    local namesMatch = event.Action:lower() == action.Name:lower()
    --the actions are performed in the same location
    local locationsMatch = (#event.Location == 0 or event.Location[1] == '' or (poi.Region and poi.Region.name:lower():find(event.Location[1]:lower()) and true or false))
    --the actions have the same kind of object or both require no object
    local objectsMatch = ((objectUsedByAction == nil and objectUsedByEvent == nil) or (objectUsedByAction and objectUsedByEvent and objectUsedByAction.type:lower() == objectUsedByEvent.Properties.Type:lower()))

    if DEBUG_VALIDATION then
        print("Names "..event.Action:lower()..' and '..action.Name:lower()..' match: '..BoolToStr(namesMatch))
        local evtLocation = event.Location[1] or '-'
        local actionLocation = "-"
        if poi.Region then
            actionLocation = poi.Region.name or '-'
        end
        print("Locations "..evtLocation..' and '..actionLocation..' match: '..BoolToStr(locationsMatch))
        print("Objects match "..BoolToStr(objectsMatch))
    end
    if
        namesMatch and locationsMatch and objectsMatch
    then
        actionMap[action.ActionId] = event.id
        eventMap[event.id] = action.ActionId
        poiMap[event.id] = poi.LocationId
        if DEBUG_VALIDATION then
            print('Mapped in actionMap '..action.ActionId..' to '..event.id)
            print('Mapped in eventMap '..event.id..' to '..action.ActionId)
            print('Mapped in poiMap '..event.id..' to '..poi.LocationId)
        end
        if objectUsedByAction and objectUsedByEvent then
            objectMap[objectUsedByAction.ObjectId] = objectUsedByEvent.id
            eventObjectMap[objectUsedByEvent.id] = objectUsedByAction.ObjectId
            if DEBUG_VALIDATION then
                print('Mapped in objectMap '..objectUsedByAction.ObjectId..' to '..objectUsedByEvent.id)
                print('Mapped in eventObjectMap '..objectUsedByEvent.id..' to '..objectUsedByAction.ObjectId)
            end
        end
        return true
    else
        if DEBUG_VALIDATION then
            print("Action "..action.Name..' and event'..event.id..' do not match!')
        end
        return false
    end
end

--TODO: find starting locations for all episodes in the valid episodes subset
--update all references to CurrentEpisode
--move peds in story
function GraphStory:ProcessActions(graphActors)
    print("GraphStory:ProcessActions --------------------------------------------------")
    local episode = self.CurrentEpisode

    local requiredObjects = Select(Where(self.graph, function(event)
        return event.Action == 'Exists' and not event.Properties.Gender
    end), function(event)
        local location = ''
        if event.Location and #event.Location > 0 then location = event.Location[1] end
        return { location = location, name = event.Properties.Type, id = event.id }
    end)

    local interactionPoiMap = {}
    local interactionProcessedMap = {}

    local actionMap = {}
    local eventMap = {}
    local objectMap = {}
    local eventObjectMap = {}
    local poiMap = {}
    -- The object needs to satisfy all the events
    local allRequiredObjectsMapped = self:MapObjectsActionsAndPoi(requiredObjects, episode, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
    if not allRequiredObjectsMapped then
        return false
    end

    if DEBUG then
        for key, value in pairs(eventObjectMap) do
            print('ProcessActions!!!!!!!!!!!!!!!!!!!!!!Mapped '..key..' to '..value)
        end
    end

    self.eventObjectMap = eventObjectMap
    self.poiMap = poiMap
    self.eventMap = eventMap

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
            firstEvent.interactionRelation = FirstOrDefault(self.temporal[firstEvent.id].relations, function(rel) return self.temporal[rel].type == 'starts_with' or self.temporal[rel].type == 'same_time' end)
            print("first event interaction relation ".. (firstEvent.interactionRelation or ''))

            firstEvent.interactionEvent = FirstOrDefault(self.graph, function(a)
                return a.id and self.temporal[a.id] and self.temporal[a.id].relations
                    and Any(self.temporal[a.id].relations, function(rel) return rel == firstEvent.interactionRelation end) end)
        end
        --if it is an interaction -> the poi has to be the same for both actors...
        local firstLocation = nil
        if poiMap[firstEvent.id] then
            firstLocation = FirstOrDefault(episode.POI, function(poi) return poi.LocationId == poiMap[firstEvent.id] end)
        end
        if not firstLocation then
            firstLocation = PickRandom(Where(episode.POI, function(poi)
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
                                (action.TargetItem.ObjectId and action.TargetItem.type == self.graph[firstEvent.Entities[2]].Properties.Type --action has as target an object of type x
                                and action.TargetItem.ObjectId == eventObjectMap[firstEvent.Entities[2]]
                                )
                            ) --the instance of the object is the one required
                        end)
                    )
                    --the location contains an action defined in the first event
            end))
        end

        if not firstLocation then
            local isInteraction = "false"
            if firstEvent.isInteraction then
                isInteraction = "true"
            end
            local locationId = interactionPoiMap[firstEvent.interactionRelation] or ''
            print('Could not find the first location \''..firstEvent.Location[1]..'\', isInteraction: '..isInteraction..' interactionLocationId: \''..locationId..'\'')
            return false
        end

        print('Actor '..a.id..' will be spawned in the location '..firstLocation.Description)

        --this is the first location -> the place where the actor or ped is first spawned
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
        self.interactionPoiMap = interactionPoiMap
        self.interactionProcessedMap = interactionProcessedMap
        self.lastEvents[a.id] = firstEvent
        self.lastLocations[a.id] = firstLocation
    end
    print("GraphStory:ProcessActions --------------------------------------------------")
    return true
end

function GraphStory:End()
    if DEBUG then
        outputConsole("GraphStory:End")
    end
    if not self.Disposed then
        self.CurrentEpisode:Destroy()
        self.Disposed = true
    end
end