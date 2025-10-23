GraphStory = class(StoryBase, function(o, spectators, logData, artifactCollectionFactory, artifactManager)
    StoryBase.init(o, spectators, maxActions)
    o.LogData = logData
    o.globalChainCounter = 0 -- Global counter for unique chain IDs

    -- Use the pre-configured artifact manager passed from Player.lua
    -- DO NOT create a new manager here - it would be empty!
    o.artifactManager = artifactManager
    if artifactManager and DEBUG then
        print("[GraphStory] Using pre-configured artifact collection manager")
    end

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
        "classroom1"
    --   "house1_sweet",
    --   "house1_stripped",
    -- --   "house3_preloaded", --NOT WORKING! The pathfinding seems flawed here, when we have 2 levels?
    -- --   "house7", --NOT WORKING! Potential issue when the link POI is located outside a region
    --   "house8_preloaded",
    --   "house9",
    -- --   "house10_preloaded", -- Not Working!
    --   "house12_preloaded", -- Working but needs the objects removed. Some flakiness exists but in general it works...
    --   "garden",
    --   "office",
    --   "office2",
    --   "common",
    --   "gym1",
    --   "gym2",
    --   "gym3"
    }
    o.Disposed = false
    o.SpawnableObjects = {
        "Cigarette",
        "MobilePhone",
        "Phone", -- Alias for MobilePhone
        -- "Drinks",
        -- "Food"
    }
    o.PickUpableObjects = {
        "Cigarette",
        "MobilePhone",
        "Drinks",
        "Food",
        "Remote"
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
        "TakeOut",
        "Stash",
        "Drink",
        "Smoke",
        "LookAtObject",
        "LookAt",
        "TalkPhone",
        "AnswerPhone",
        "HangUp",
        "SmokeIn",
        "SmokeOut",
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
    o.spatial = nil
    o.materializedObjects = {}
    o.lastEvents = {}
    o.lastLocations = {}
    o.nextEvents = {}
    o.nextLocations = {}
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
        for k,v in pairs(o.temporal) do
            if k then
                v.key = k
            end
        end
        if o.graph['temporal_abs'] then
            o.graph['temporal_abs'] = nil
        end
        if o.graph['spatial'] then
            o.spatial = o.graph['spatial']
            o.graph['spatial'] = nil
            if DEBUG then
                print("GraphStory: loaded spatial constraints")
            end
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
end)

function GraphStory:Play()
    if DEBUG then
        print("GraphStory: Loading dynamic episodes..")
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

--choose a random valid episode
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    self.Episodes = self:GetValidEpisodes(requiredActors)
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
            -- Start artifact collection via artifact manager
            if ARTIFACT_COLLECTION_ENABLED and self.artifactManager then
                self.artifactManager:startScheduledCollection(
                    -- Collection callback: story builds frameContext
                    function(frameId, triggerCollection)
                        -- Build frameContext for each spectator
                        local anyCollectionTriggered = false
                        for _, spectator in ipairs(self.Spectators) do
                            if DEBUG_SCREENSHOTS then
                                print('Triggering collection for spectator '..spectator:getData('id')..' frame '..frameId..' fadedCamera '..tostring(spectator:getData('fadedCamera')))
                            end
                            if spectator:getData('fadedCamera') then
                                if DEBUG_SCREENSHOTS then
                                    print("[GraphStory] The camera was faded, continue with the collection")
                                end
                                -- Build game-agnostic frameContext (no spectator entity!)
                                local frameContext = {
                                    playerId = spectator:getData('id'),
                                    storyId = self.Id,
                                    playerName = spectator.name,
                                    timestamp = getTickCount and getTickCount() or 0,
                                    cameraId = spectator:getData('id')
                                }

                                -- Trigger collection with frameContext
                                triggerCollection(frameContext)
                                anyCollectionTriggered = true
                            else
                                if DEBUG_SCREENSHOTS then
                                    print("[GraphStory] The camera was not faded, skipping the collection")
                                end
                            end
                        end

                        -- If no collection was triggered, manually schedule the next collection
                        if not anyCollectionTriggered then
                            if DEBUG_SCREENSHOTS then
                                print("[GraphStory] No collection triggered (camera not faded), scheduling next collection")
                            end
                            -- Pass nil to triggerCollection to indicate skipped collection
                            -- The manager will handle the nil check and schedule next collection
                            triggerCollection(nil)
                        end
                    end,
                    -- Completion callback: all collection finished
                    function()
                        if DEBUG_SCREENSHOTS then
                            print("[GraphStory] All artifact collection finished")
                        end

                        -- If story requested termination, complete it now
                        if self.pendingTermination then
                            self:_completeTermination()
                        end
                    end
                )
            end

            -- Separate timer for MAX_STORY_TIME timeout (story's responsibility)
            self.StoryTimeoutTimer = Timer(function()
                local elapsedTime = os.time() - self.StartTime
                print('Elapsed time '..elapsedTime)
                if elapsedTime > MAX_STORY_TIME then
                    for _, spectator in ipairs(self.Spectators) do
                        local file = File(LOAD_FROM_GRAPH..'_out/'..self.Id..'/'..spectator:getData('id') .. '/MAX_STORY_TIME_EXCEEDED')
                        if file then
                            file:setPos(file:getSize())
                            file:write('Maximum story time of '..MAX_STORY_TIME..' was exceeded. The story ended unexpectedly.')
                            file:flush()
                            file:close()
                        end
                    end

                    -- Force terminate story (timeout)
                    self:End("MAX_STORY_TIME exceeded")
                    self.StoryTimeoutTimer:destroy()
                end
            end, 1000, 0) -- Check every second
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
        print('All the requirements were fullfilled for the subset '..join(';', Select(currentSubset, function(e) return e.name end)))
        return currentSubset
    elseif #episodes == 0 then
        if DEBUG_VALIDATION then
            print("No episodes left to evaluate but all the requirements were not fullfilled^^^.")
        end
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
                if DEBUG_VALIDATION then
                    print("No further valid episodes exist.")
                    print('Required locations '..join(';', requiredLocations))
                    print('Required objects '..join(';', Select(requiredObjects, function(e) return e.name end)))
                    print('Required actions '..join(';', Select(requiredActions, function(e) return e.name..' - '..e.location..' -> '..(e.target or '') end)))
                end
                return {}  --If I still have requirements and episodes but there's no further valid episode => there's no valid episode subset
            end
        end
    end
    if DEBUG_VALIDATION then
        print("No episodes left to explore but all the requirements were not yet fullfilled.")
        print('Required locations '..join(';', requiredLocations))
        print('Required objects '..join(';', Select(requiredObjects, function(e) return e.name end)))
        print('Required actions '..join(';', Select(requiredActions, function(e) return e.name..' - '..e.location..' -> '..(e.target or '') end)))
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

    -- This function is used only to check if the events requested in the graph can be simulated in the episode with the pre-existing 3D engine entities.
    -- Partial matches are allowed at this point, because we are exploring individual contextual episodes, and walking through other connected episodes.
    -- In the end, if a sub-tree of linked episodes that satisfy all the requirements is found, then all the found episodes are wrapped in a meta-episode, which will be used to play the story.
    -- At this point, the function below works on granular episodes (non-meta-episodes), so it is allowed to have partial matches.
    self:MapObjectsActionsAndPoi(requiredObjects, episode, actionMap, eventMap, objectMap, eventObjectMap, poiMap)

    -- Validate spatial constraints for mapped objects
    local spatiallyValid, failedObjects = self:ValidateSpatialConstraints(episode, eventObjectMap)
    if not spatiallyValid then
        if DEBUG_VALIDATION then
            print('[GraphStory] Episode ' .. episode.name .. ' discarded due to unsatisfiable spatial constraints for objects: ' .. join(', ', failedObjects))
        end
        -- Return early with zero score to discard this episode
        res = {
            setCoverScore = 0,
            requiredLocations = requiredLocations,
            requiredObjects = requiredObjects,
            requiredActions = requiredActions
        }
        self.validMemo[episode.name] = res
        return res
    end

    for eventRoId, potentialRealObjects in pairs(eventObjectMap) do
        if DEBUG_VALIDATION then
            print('!!!!!!!!!!!!!!!!!!!!!!Mapped '..eventRoId..' to '..#potentialRealObjects..' potential chains of real objects')
        end
        table.insert(validObjects, {id = eventRoId})
    end

    for key, potentialActions in pairs(eventMap) do
        if DEBUG_VALIDATION then
            print('!!!!!!!!!!!!!!!!!!!!!!Mapped action ('..self.graph[key].Action..')'..key..' to '..#potentialActions..' potential chains of real actions')
        end
        table.insert(validActions, {id = key, name = self.graph[key].Action, location = self.graph[key].Location})
    end
    -- Remove the actions that were mapped to something from the list of required actions for the episode to be valid
    local requiredActions = Where(requiredActions, function(ra) return not eventMap[ra.id] end)

    Where(requiredActions, function(ra)
        local res = Any(self.Interactions, function(a) return
                a:lower() == ra.name:lower()
            end)
            or Any(self.MiddleActions, function(a) return
                a:lower() == ra.name:lower()
            end)
            or Any(episode.POI, function(poi)
                if DEBUG_ACTION_VALIDATION then
                    if poi.Region then
                        print('***'..poi.Region.name..'')
                    else
                        print('***!!'..poi.Description..' does not have a region')
                    end
                end
                return
                    poi.Region and
                    Any(poi.allActions, function(a)
                        if DEBUG_ACTION_VALIDATION then
                            print('**********'..a.Name)
                            if a.TargetItem and a.TargetItem.ObjectId then
                                print('**********->'..a.TargetItem.ObjectId..'('..tostring(a.TargetItem.dynamicString)..')')
                            elseif a.TargetItem and a.TargetItem.Region then
                                print('**********->'..a.TargetItem.Region.name)
                            end
                        end
                        return a.Name:lower() == ra.name:lower() and (
                            ra.name == 'Move' -- The action is of type move.
                            or not a.TargetItem --The action has no target
                            or a.TargetItem and inList(a.TargetItem.type, self.SpawnableObjects) --The action has as target a spawnable object
                            or a.TargetItem and a.TargetItem.ObjectId and objectMap[a.TargetItem.ObjectId]) --The action has as target a real object and that object is valid
                    end)
                    and (poi.Region.name:lower():find(ra.location:lower()) and true or false )
            end)

        if not res and DEBUG_VALIDATION then
            print('Episode '..episode.name..' - the action '..ra.name..' with target '..(ra.target or '')..' does not exist in region '..ra.location..' or at all in the whole episode!')
        end

        if res then
            table.insert(validActions, ra)
        end
        return res
    end)

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
    if DEBUG_VALIDATION then
        print('Result of ValidateEpisode '..episode.name)
        print('Required locations '..join(';', res.requiredLocations))
        print('Required objects '..join(';', Select(res.requiredObjects, function(e) return e.name end)))
        print('Required actions '..join(';', Select(res.requiredActions, function(e) return e.name..' - '..e.location..' -> '..(e.target or '') end)))
    end

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

function GraphStory:GetNextEvent(currentEventId, actorId)
    local nextEvents = {}
    local next = currentEventId
    local result = nil
    repeat
        if self.temporal[next].next then
            if isArray(self.temporal[next].next) then
                nextEvents = concat(nextEvents, self.temporal[next].next)
            else
                nextEvents = concat(nextEvents, {self.temporal[next].next})
            end
        end

        if #nextEvents == 0 then
            result = nil
            break
        end
        next = nextEvents[1]
        table.remove(nextEvents, 1)
        local event = self.graph[next]
        if event.Entities[1] == actorId then
            result = next
            break
        end
    until(nextEvents == 0)

    return result
end

function GraphStory:FindPreviousEventId(eventId, actorId)
    -- starting from the current event, find the previous event that has the same actor
    -- temporal does not have a previous field, so we need to go through the graph
    local previousEvents = {}

    repeat
        local previousTemporal = FirstOrDefault(self.temporal, function(temporal)
            return self:IsEventInNextTemporal(eventId, temporal)
        end)

        if previousTemporal then
            local previousEvent = self.graph[previousTemporal.key]
            if previousEvent.Entities[1] == actorId then
                return previousTemporal.key
            end
        end
    until(#previousEvents == 0)
    return nil
end

function GraphStory:IsEventInNextTemporal(eventId, temporal)
    if isArray(temporal.next) then
        return Any(temporal.next, function(e) return e == eventId end)
    else
        return temporal.next == eventId
    end
end

function GraphStory:GetValidEpisodes(requiredActors)
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

    local requiredObjects = {}
    for _, requiredActor in ipairs(requiredActors) do
        local eventId = self.temporal.starting_actions[requiredActor.id]
        while eventId ~= nil do
            local objectId = nil
            if self.graph[eventId].Entities[3] then
                objectId = self.graph[eventId].Entities[3]
            elseif self.graph[eventId].Entities[2] then
                objectId = self.graph[eventId].Entities[2]
            end

            if objectId and self.graph[objectId] and self.graph[objectId].Properties then
                if self.graph[objectId].Properties.Gender then
                    objectId = nil
                end
            elseif objectId then
                print("Warning! The event seems invalid: "..objectId)
            end

            if objectId and LastIndexOf(requiredObjects, objectId, function(rObject, __) return rObject.id == objectId end) == -1 then
                if DEBUG then
                    print("Required object "..objectId)
                end

                local existsEvent = self.graph[objectId]
                local location = ''
                if existsEvent.Location and #existsEvent.Location > 0 then location = existsEvent.Location[1] end

                table.insert(requiredObjects, { location = location, name = existsEvent.Properties.Type, id = existsEvent.id })
            end

            eventId = self:GetNextEvent(eventId, requiredActor.id)
        end
    end

    if DEBUG then
        print("********Finished retrieving the required objects*******")
    end
--a list of all the objects and their locations (temporary objects i.e. cigarette should not be checked )
    -- local requiredObjects = Select(Where(self.graph, function(event)
    --     return event.Action == 'Exists' and not event.Properties.Gender
    -- end), function(event)
    --     local location = ''
    --     if event.Location and #event.Location > 0 then location = event.Location[1] end
    --     return { location = location, name = event.Properties.Type, id = event.id }
    -- end)
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

---This function iterates through all the POIs available in an episode (it can be a meta episode that is a composition of multiple local episodes),
---and for each POI, it finds and maps a chain of events that happen in the same location (both forward and backward in time)
---starting from the first eventsWithObjectAsTarget that has the same action and location as the action with the object as target.
---
---This does not guarantee that all the events from the eventsWithObjectAsTarget are mapped to simulator actions, and it can even result in duplicates.
---@param episode any
---@param ro any The required object (the one that is used in the event)
---@param eventsWithObjectAsTarget any[] The events that have the object as target
function GraphStory:FindAllValidActionsAndPois(episode, ro, eventsWithObjectAsTarget)
    return Select(episode.POI, function(poi)
        local actionMap = {}
        local eventMap = {}
        local objectMap = {}
        local eventObjectMap = {}
        local poiMap = {}

        if DEBUG_VALIDATION then
            print('Assessing actions in poi '..poi.Description..' in region '..poi.Region.name)
        end

        -- Starting from the action with the object as target,
        local actionWithMatchingObject = FirstOrDefault(poi.allActions, function(a) return a.TargetItem and a.TargetItem.ObjectId and a.TargetItem.type == ro.name end)

        -- If in the current POI an action with the required object does not exist but also there is no event in the GEST with such an object, just map them.
        -- There will be no action in the simulation with the given object, but it might still be required to just exist.
        -- **Note** that an object is either used in an event or it is just a requirement of the episode and never used by anyone in an episode.
        if not actionWithMatchingObject then
            if DEBUG_VALIDATION then
                print("Action with matching object does not exist!")
            end
            -- if there is no actual action in the graph with the object, it means that the object is simply a requirement to exist in the environment.
            if #eventsWithObjectAsTarget == 0 then
                local episodeObject = FirstOrDefault(episode.Objects, function(eO) return eO.ObjectId and eO.type == ro.name end)
                if episodeObject then
                    actionWithMatchingObject = {
                        Name = "none",
                        TargetItem = {
                            ObjectId = episodeObject.ObjectId
                        }
                    }
                elseif DEBUG_VALIDATION then
                    print("This object "..ro.name.." does not exist in the episode!")
                end
            else
                -- An action with the object was not found in the current POI, but the object is used in some actions within the episode.
                -- Return NULL, to discard this POI from the current evaluation.
                return nil
            end
        end

        if DEBUG_VALIDATION then
            print("Action with matching object "..actionWithMatchingObject.Name)
        end

        -- The object is not used in any of the events, but it is simply a requirement of the episode.
        if #eventsWithObjectAsTarget == 0 then
            print("The object is not used in any events "..ro.name)
            eventObjectMap[ro.id] = actionWithMatchingObject.TargetItem.ObjectId
            objectMap[actionWithMatchingObject.TargetItem.ObjectId] = ro.id
            return {
                actionMap = {},
                eventMap = {},
                objectMap = objectMap,
                eventObjectMap = eventObjectMap,
                poiMap = {}
            }
        end

        -- find all matching events (same action name and location)
        local eventsMatchingActionAndObject = Where(eventsWithObjectAsTarget, function(event)
            local isMatchingAction = event.Action:lower() == actionWithMatchingObject.Name:lower()
            local isAnyActionLocationAllowed = #event.Location == 0 or event.Location == ''
            local isMatchingLocationInRegion = (poi.Region and poi.Region.name:lower():find(event.Location[1]:lower()) and true or false)
            local isMatchingLocation = (isAnyActionLocationAllowed or isMatchingLocationInRegion)
            return isMatchingAction and isMatchingLocation
        end)

        if #eventsMatchingActionAndObject == 0 then
            if DEBUG_VALIDATION then
                print("No events matching action exist!")
            end
            return nil
        end

        if DEBUG_VALIDATION then
            print('Found '..#eventsMatchingActionAndObject..' events matching action in POI '..poi.Description)
            for _, event in ipairs(eventsMatchingActionAndObject) do
                print('  Event matching action: '..event.id)
            end
        end

        -- Map all matching events to this POI and trace their event chains
        local allEventsMatched = true
        for _, startingEvent in ipairs(eventsMatchingActionAndObject) do
            local currentAction = actionWithMatchingObject
            local currentEvent = startingEvent

            -- The action and event are guaranteed to be matching at this point
            if not self:MatchEventAndAction(currentAction, currentEvent, poi, actionMap, eventMap, objectMap, eventObjectMap, poiMap) then
                if DEBUG_VALIDATION then
                    print("[ERROR] Event "..currentEvent.id.." and action can't be matched. Something went seriously wrong!")
                end
                allEventsMatched = false
                break
            else
                if DEBUG_VALIDATION then
                    print("Successfully matched event "..currentEvent.id.." to action in POI "..poi.Description)
                end
            end

            --The PickUp action was skipped initially because if the object is to bo moved afterwards, then we do not want to enforce the same location.
            --But now, we are only mapping all the actions that occur in the POI, until the next Move action (that would change the location anyway).
            --Therefore, when a PickUp action was started from, it will not find previous action candidates if the actor Moves with the picked up object.
            --If the graph specifies that an action has to be executed somewhere else with the picked up object that was moved, then the current logic will fail, because we will never find an object that otherwise is picked up in a location
            --where it will be moved in the future.

            ----verify going back in time until a Move is found if all the  actions have matching events (same location, same target objects)
            local previousActionsCandidates = Where(poi.allActions, function(a)
                return
                    a.Name:lower() ~= 'move' -- this action changes the location and marks the end of the chain of actions
                    and (
                        (not isArray(a.NextAction) and a.NextAction == currentAction)
                        or (isArray(a.NextAction) and inList(currentAction, a.NextAction))
                    )
            end)
            while previousActionsCandidates and #previousActionsCandidates > 0 do
                local previousEventId = self:FindPreviousEventId(currentEvent.id, currentEvent.Entities[1])
                -- In the current chain of actions, if there is no matching event, then the current POI is invalid (no chain of actions to match the chain of events exists in this location)
                if not previousEventId then
                    if DEBUG_VALIDATION then
                        print("Previous event was null!")
                    end
                    allEventsMatched = false
                    break
                end
                local previousEvent = self.graph[previousEventId]

                if not previousEvent then
                    if DEBUG_VALIDATION then
                        print("Previous event was null even though the previous event id was "..previousEventId)
                    end
                    allEventsMatched = false
                    break
                end

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
                    allEventsMatched = false
                    break
                else
                    print("Previous action "..previousAction.Name)
                end

                currentAction = previousAction
                previousActionsCandidates = Where(poi.allActions, function(a) return a.Name:lower() ~= 'move' and (((not isArray(a.NextAction) or #a.NextAction == 1) and a.NextAction == currentAction) or (isArray(a.NextAction) and inList(currentAction, a.NextAction))) end)
                currentEvent = previousEvent
            end

            if not allEventsMatched then
                break
            end

            ----verify going forward in time if all the actions have matching events
            currentAction = actionWithMatchingObject
            currentEvent = startingEvent
            while currentAction and currentAction.NextAction and self.temporal[currentEvent.id].next do
                local nextEventId = self:GetNextEvent(currentEvent.id, currentEvent.Entities[1])
                if not nextEventId then
                    if DEBUG_VALIDATION then
                        print("Next event was null but next action exists!")
                    end
                    allEventsMatched = false
                    break
                end
                local nextEvent = self.graph[nextEventId]

                if
                        nextEvent.Action:lower() ~= 'move'
                    and nextEvent.Action:lower() ~= 'give'
                    and nextEvent.Action:lower() ~= 'inv-give'
                    and nextEvent.Action:lower() ~= 'lookatobject'
                    and nextEvent.Action:lower() ~= 'lookat'
                then
                    local nextActions = { currentAction.NextAction }
                    if isArray(currentAction.NextAction) then
                        nextActions = currentAction.NextAction
                    end

                    --if multiple possible next actions, choose the first one that matches the next event
                    currentAction = FirstOrDefault(nextActions, function(action)
                        if DEBUG_VALIDATION then
                            print("Next action candidate "..action.Name)
                        end
                        return self:MatchEventAndAction(action, nextEvent, poi, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
                    end)
                    if not currentAction then
                        if DEBUG_VALIDATION then
                            print("There is no next action that matches the next event!")
                        end
                        allEventsMatched = false
                        break
                    end

                    if DEBUG_VALIDATION then
                        print("Next action that also matches next event "..currentAction.Name)
                    end
                else
                    print('The event does not follow the chain of actions. Event: '..nextEvent.Action..' Action: '..currentAction.Name)
                    break
                end
                currentEvent = nextEvent
            end

            if not allEventsMatched then
                break
            end
        end

        if not allEventsMatched then
            return nil
        end

        if DEBUG_VALIDATION then
            print("This poi is valid, returning ")
        end

        return {
            actionMap = actionMap,
            eventMap = eventMap,
            objectMap = objectMap,
            eventObjectMap = eventObjectMap,
            poiMap = poiMap,
            poiDescription = poi.Description,
            poiRegion = poi.Region.name,
            poiLocationId = poi.LocationId
        }
    end)
end

---This function iterates through all the required objects in the apisode, then starting from the object:
------1. it finds the events that have the object as target (eventsWithObjectAsTarget)
------2. it finds the POIs that contain actions with the same kind of object as target
------3. starting from the first action with that object (actionWithMatchingObject), it finds the first event from eventsWithObjectAsTarget with the same action and location (indirectly, the same object as well)
------4. it maps the pairs of objects, actions and locations between graph and simulator entities (action <-> event action, object <-> second event entity, name of poi region <-> first event location if any)
------5. it then iterates through all previous actions and events, mapping them as well (until a Move action is found - and the location would be changed)
------6. it then iterates through all next actions and events, mapping them as well (until a Move action is found - and the location would be changed)
------7. it returns the action to event map (actionMap), event to action map (eventMap), object to event object map (objectMap), event object to simulator objects map (eventObjectMap) and event id to location id map (poiMap)
---
---In short: it finds the matching events and actions that are related to the required object and maps object, events, and locations.
---
---Currently, the following actions are not mapped: 'Give', 'Inv-Give', 'LookAtObject', 'Move'.
---All the process is actor agnostic, meaning that the same object can be used by multiple actors in the same episode.
---The purpose of the function is two fold:
---1. To verify if the episode is valid (if all the requierd objects from the graph are present in the episode and if they are used in the same way as in the graph)
---2. To map the objects, actions and locations between the graph and simulator entities (the mapping is done in the actionMap, eventMap, objectMap, eventObjectMap and poiMap)
---
---The map can be used later during simulation run-time to decide where and with what objects exactly in the simulation environment an actor should perform an event.
---The map has to be then exhaustive, meaning that from all possible actions with objects requested in the graph, all possible places in the simulation environment where the action can be performed are mapped.
---This then means that the maps should be one to many:
---   ** actionMap[graphEventId] = {simulatorActionId1, simulatorActionId2, ...}
---   ** eventMap[simulatorActionId] = {graphEventId1, graphEventId2, ...}
---   ** objectMap[simulatorObjectId] = {graphObjectId1, graphObjectId2, ...}
---   ** eventObjectMap[graphObjectId] = {simulatorObjectId1, simulatorObjectId2, ...}
---   ** poiMap[graphEventId] = {simulatorLocationId1, simulatorLocationId2, ...}
--- Validate spatial constraints for mapped objects in an episode
--- Checks if at least one valid spatial configuration exists for each object with constraints
---
--- @param episode any The episode being validated
--- @param eventObjectMap table Map of event object IDs to chains of real object mappings
--- @return boolean True if all spatial constraints can be satisfied
--- @return table|nil Objects that failed spatial validation (nil if all valid)
function GraphStory:ValidateSpatialConstraints(episode, eventObjectMap)
    if not self.spatial then
        return true, nil -- No spatial constraints defined
    end

    local failedObjects = {}

    -- Check each object that has spatial constraints
    for eventObjectId, spatialConstraintDef in pairs(self.spatial) do
        if spatialConstraintDef.relations and #spatialConstraintDef.relations > 0 then
            local relations = spatialConstraintDef.relations

            if DEBUG_VALIDATION then
                print("[GraphStory] Validating spatial constraints for object " .. eventObjectId)
            end

            -- Check if this object is mapped
            if eventObjectMap[eventObjectId] and #eventObjectMap[eventObjectId] > 0 then
                -- For each relation, check if target object can be found
                local allRelationsCanBeSatisfied = true

                for _, relation in ipairs(relations) do
                    local targetObjectId = relation.target
                    local relationType = relation.type

                    if DEBUG_VALIDATION then
                        print("[GraphStory] Checking if " .. eventObjectId .. " " .. relationType .. " " .. targetObjectId .. " can be satisfied")
                    end

                    -- Check if target object is mapped
                    if eventObjectMap[targetObjectId] and #eventObjectMap[targetObjectId] > 0 then
                        -- Find at least one valid combination of source and target objects that satisfy the constraint
                        local foundValidCombination = false

                        for _, sourceChain in ipairs(eventObjectMap[eventObjectId]) do
                            local sourceObjectId = sourceChain.value

                            if sourceObjectId == 'spawnable' then
                                -- Spawnable objects don't have fixed positions
                                foundValidCombination = true
                                break
                            end

                            local sourceObject = FirstOrDefault(episode.Objects, function(o)
                                return o.ObjectId == sourceObjectId
                            end)

                            if sourceObject and sourceObject.position then
                                -- Try to find a target object that satisfies the constraint
                                for _, targetChain in ipairs(eventObjectMap[targetObjectId]) do
                                    local targetRealObjectId = targetChain.value

                                    if targetRealObjectId ~= 'spawnable' then
                                        local targetObject = FirstOrDefault(episode.Objects, function(o)
                                            return o.ObjectId == targetRealObjectId
                                        end)

                                        if targetObject and targetObject.position then
                                            -- Get object types for dynamic threshold calculation
                                            local sourceType = nil
                                            local targetType = nil
                                            if self.graph[eventObjectId] and self.graph[eventObjectId].Properties then
                                                sourceType = self.graph[eventObjectId].Properties.Type
                                            end
                                            if self.graph[targetObjectId] and self.graph[targetObjectId].Properties then
                                                targetType = self.graph[targetObjectId].Properties.Type
                                            end

                                            -- Get element references if available
                                            local sourceElement = sourceObject.element or nil
                                            local targetElement = targetObject.element or nil

                                            -- Validate the spatial relation
                                            local isValid = self.SpatialCoordinator:ValidateRelation(
                                                sourceObject.position,
                                                targetObject.position,
                                                targetObject.rotation or {x=0, y=0, z=0},
                                                relationType,
                                                sourceType,
                                                targetType,
                                                sourceElement,
                                                targetElement
                                            )

                                            if isValid then
                                                foundValidCombination = true
                                                if DEBUG_VALIDATION then
                                                    print("[GraphStory] ✓ Found valid combination: " .. sourceObjectId .. " " .. relationType .. " " .. targetRealObjectId)
                                                end
                                                break
                                            end
                                        end
                                    end
                                end

                                if foundValidCombination then
                                    break
                                end
                            end
                        end

                        if not foundValidCombination then
                            if DEBUG_VALIDATION then
                                print("[GraphStory] ✗ No valid combination found for " .. eventObjectId .. " " .. relationType .. " " .. targetObjectId)
                            end
                            allRelationsCanBeSatisfied = false
                            break
                        end
                    else
                        if DEBUG_VALIDATION then
                            print("[GraphStory] Target object " .. targetObjectId .. " not mapped - spatial constraint cannot be validated during episode validation")
                        end
                        -- Target not mapped means we can't validate this constraint at episode level
                        -- It will be validated at runtime - skip this relation
                    end
                end

                if not allRelationsCanBeSatisfied then
                    table.insert(failedObjects, eventObjectId)
                    if DEBUG_VALIDATION then
                        print("[GraphStory] Episode " .. episode.name .. " cannot satisfy spatial constraints for object " .. eventObjectId)
                    end
                end
            else
                if DEBUG_VALIDATION then
                    print("[GraphStory] Object " .. eventObjectId .. " not mapped, skipping spatial validation")
                end
            end
        end
    end

    local isValid = #failedObjects == 0
    return isValid, #failedObjects > 0 and failedObjects or nil
end

---
---CURRENT GRAPH EVENT COVERAGE
---Only events representing actions with objects are mapped with the exception of 'Exists', 'Move', 'give', 'receive', 'look at object', and interactions are not mapped.
---(Explanation for interactions: when the evaluation for an object is started, only non-interaction events are considered. In general, by going forward or backward in the chain of events, it is not possible to reach an interaction starting from a non-interaction event.)
---If the same object is used in multiple events, a random chain of events is selected starting from the event with the object. The same object can be used in multiple actions and events, but the mapping will be done only once.
---Later on, at runtime, currently only the poiMap and the eventObjectMap are used.
---Problem1: 2 actors can choose the same POI when they have a same_time constraint leading to interlocking.
---Mitigation: there should be one to many relationships between events and pois / actions. The final POI should be selected at runtime, based on whether the POI is free or not.
---
---Additional consideration: if we employ a one to many relationship between event object and simulator objects, respectively between event and simulator actions, at runtime when 2 actors should use the same object,
---we need to ensure that the selected POI contains the same object as the one the first actor used.
---(e.g, both should sit donw on the same sofa, bot there are 3 sofas in the room. The first actor chooses a poi with sofa 1, the second actor then should choose from free POIs with the same sofa - sofa 1.)
---@param requiredObjects any
---@param episode any
---@param actionMap any
---@param eventMap any
---@param objectMap any
---@param eventObjectMap any
---@param poiMap any
---@return boolean
function GraphStory:MapObjectsActionsAndPoi(requiredObjects, episode, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
    return All(requiredObjects, function(ro)
        if eventObjectMap[ro.id] and #eventObjectMap[ro.id] > 0 then return true end
        if DEBUG_VALIDATION and not eventObjectMap[ro.id] then
            print("The object "..ro.id..':'..ro.name..' ()'..(ro.location or '')..' is not mapped in any of event objects map')
            for k, v in pairs(eventObjectMap) do
                print(k)
            end
        end

        if Any(self.SpawnableObjects, function(o) return o:lower() == ro.name:lower() end) then
            eventObjectMap[ro.id] = {{value = 'spawnable', chainId = -1}}
            return true
        end

        local eventsWithObjectAsTarget = Where(self.graph, function(event)
            return
                --The action was not already processed
                not actionMap[event.id]
                --The event is of type action (LookAt/LookAtObject will be individually mapped during runtime, so we are not mapping it here)
                and event.Action ~= 'Exists'
                and event.Action ~= 'LookAt'
                and event.Action ~= 'LookAtObject'
                and event.Action ~= 'TakeOut'
                and event.Action ~= 'Stash'
                and event.Action ~= 'AnswerPhone'
                and event.Action ~= 'TalkPhone'
                and event.Action ~= 'HangUp'
                and event.Action ~= 'SmokeIn'
                and event.Action ~= 'Smoke'
                and event.Action ~= 'SmokeOut'
                -- and event.Action ~= 'Drink'
                -- and event.Action ~= 'Eat'
                --The event is not interaction and is with the required object
                and #event.Entities == 2 and event.Entities[2] == ro.id
                --The event is in the same location as the required object (this event will not be mapped if the object was moved to a different location)
                --The consequence of the check below is that only the events occuring in the same location where the object initially exists are considered.
                and (#event.Location == 0 or event.Location[1] == '' or event.Location[1]:lower():find(ro.location:lower()))
            end
        )

        if DEBUG_VALIDATION then
            print("Events with object as target:vvv")
            for _, e in ipairs(eventsWithObjectAsTarget) do
                print("Event with object "..ro.name..' as target '..e.id)
            end
        end

        local allPotentialMatchingPoiData =
            self:FindAllValidActionsAndPois(episode, ro, eventsWithObjectAsTarget)


        local anyMatchesFound = self:AggregatePoiData(allPotentialMatchingPoiData, objectMap, eventObjectMap, actionMap, eventMap, poiMap)
        if not anyMatchesFound and DEBUG then
            print('Episode '..episode.name..' was discarded because the object '..ro.name..' does not exist in region '..ro.location..' or at all or a matching chain of actions could not be found for the object')
        end
        if not anyMatchesFound then
            print("Could not find actions required for the object "..ro.name..' id '..ro.id..' in location '..ro.location)
            return false
        end

        return true
    end)
end

function GraphStory:AggregatePoiData(poiDatas, objectMap, eventObjectMap, actionMap, eventMap, poiMap)
    local anyMatchesFound = false
    for poiIndex, poiData in ipairs(poiDatas) do
        if poiData and poiIndex then
            anyMatchesFound = true

            -- Increment global counter and create unique chain ID
            self.globalChainCounter = self.globalChainCounter + 1
            local chainId = (poiData.poiDescription or "unknown") .. "_" .. (poiData.poiRegion or "unknown") .. "_" .. (poiData.poiLocationId or poiIndex) .. "_" .. self.globalChainCounter

            -- Process objectMap
            for k, v in pairs(poiData.objectMap) do
                if not objectMap[k] then
                    objectMap[k] = {}
                end
                table.insert(objectMap[k], {value = v, chainId = chainId})
            end

            -- Process eventObjectMap
            for k, v in pairs(poiData.eventObjectMap) do
                if not eventObjectMap[k] then
                    eventObjectMap[k] = {}
                end
                table.insert(eventObjectMap[k], {value = v, chainId = chainId})
            end

            -- Process actionMap
            for k, v in pairs(poiData.actionMap) do
                if not actionMap[k] then
                    actionMap[k] = {}
                end
                table.insert(actionMap[k], {value = v, chainId = chainId})
            end

            -- Process eventMap
            for k, v in pairs(poiData.eventMap) do
                if not eventMap[k] then
                    eventMap[k] = {}
                end
                table.insert(eventMap[k], {value = v, chainId = chainId})
            end

            -- Process poiMap
            for k, v in pairs(poiData.poiMap) do
                if not poiMap[k] then
                    poiMap[k] = {}
                end
                table.insert(poiMap[k], {value = v, chainId = chainId})
            end
        end
    end
    return anyMatchesFound
end

---This function verifies if the action name and the event action name are equal, if the action location is the same as the event location and if the action object is the same as the event object or both require no object.
---If the action and event match, the action map, event map, object map, event object map and poi map are updated with the corresponding GEST - Simulator action, and location ids. The objects are mapped only if they are used in the action and event.
---@param action any --The action to be matched
---@param event any --The event to be matched
---@param poi any --The poi where the action-event is located
---@param actionMap any --The current map of actions
---@param eventMap any --The current map of events
---@param objectMap any --The current map of objects
---@param eventObjectMap any --The current map of event objects
---@param poiMap any --The current map of poi
---@return boolean A boolean value indicating if the action and event matched
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
    -- All the objects that exist in the graph MUST be matched in the (meta)episode.
    -- The function below, already works with the meta episode.
    local allRequiredObjectsMapped = self:MapObjectsActionsAndPoi(requiredObjects, episode, actionMap, eventMap, objectMap, eventObjectMap, poiMap)
    if not allRequiredObjectsMapped then
        return false
    end

    self.eventObjectMap = eventObjectMap
    self.poiMap = poiMap
    self.eventMap = eventMap

    if DEBUG then
        self:DebugMap()
    end

    for _,a in ipairs(graphActors) do
        print(a.id)
        self.actionsQueues[a.id] = {}
        --find the first event for the current actor
        local firstEvent = FirstOrDefault(self.graph, function(event)
            return event.id == self.temporal['starting_actions'][a.id]
        end)
        if not firstEvent then
            print('Could not find the first event for actor '..a.id)
            return false
        elseif DEBUG then
        end
        print('First event: '..firstEvent.id..' in location '..firstEvent.Location[1]..' with actor '..firstEvent.Entities[1])

        local firstLocation = PickRandom(Where(self.CurrentEpisode.POI, function(poi)
            local eventLocation = ""
            if firstEvent.Location and firstEvent.Location[1] then
                eventLocation = firstEvent.Location[1]
            end
        return not poi.isBusy and poi.Region.name:lower():find(eventLocation:lower()) end))

        if not firstLocation then
            print("Error: could not find a valid first location for event "..firstEvent.id)
            return false
        end

        -- print('Actor '..a.id..' will be spawned in the location '..firstLocation.Description)

        -- --this is the first location -> the place where the actor or ped is first spawned
        firstLocation.isBusy = true
        local ped = FirstOrDefault(self.CurrentEpisode.peds, function(p) return p:getData('id') == a.id end)
        print('[GraphStory.ProcessActions] '..ped:getData('id')..': Location '..firstLocation.Description..' is set to busy')
        ped:setData('startingPoiIdx', LastIndexOf(episode.POI, firstLocation))
        ped.interior = firstLocation.Interior
        ped.position = firstLocation.position
        ped.rotation = Vector3(0,0,firstLocation.Angle)

        firstEvent.isStartingEvent = true
        self.interactionPoiMap = interactionPoiMap
        self.interactionProcessedMap = interactionProcessedMap
        self.nextEvents[a.id] = firstEvent
        self.nextLocations[a.id] = firstLocation
    end
    print("GraphStory:ProcessActions --------------------------------------------------")
    return true
end

function GraphStory:DebugMap()
    print("GraphStory:DebugMap --------------------------------------------------")

    -- Chain analysis summary
    local chainStats = {}
    for key, value in pairs(self.eventObjectMap) do
        for _, v in ipairs(value) do
            chainStats[v.chainId] = (chainStats[v.chainId] or 0) + 1
        end
    end

    print('Chain Usage Summary:')
    for chainId, count in pairs(chainStats) do
        print('Chain ' .. chainId .. ' is used by ' .. count .. ' mappings')
    end
    local chainCount = 0
    for _ in pairs(chainStats) do chainCount = chainCount + 1 end
    print('Total chains created: ' .. chainCount .. ' (each POI gets unique chain ID to prevent actor conflicts)')

    print('Event Objects')
    for key, value in pairs(self.eventObjectMap) do
        print('Event object '..key..' has '..#value..' potential values')
        if #value > 10 then
            print('WARNING: Object '..key..' has excessive mappings ('..#value..'). This may indicate chain ID generation issues.')
        end
        for _, v in ipairs(value) do
            print('Mapped '..key..' to '..v.value..' and chain '..v.chainId)
        end
    end
    print('POIs')
    for key, value in pairs(self.poiMap) do
        print('POI '..key..' has '..#value..' potential values')
        for _, v in ipairs(value) do
            print('Mapped '..key..' to '..v.value..' and chain '..v.chainId)
        end
    end
    print('Events')
    for key, value in pairs(self.eventMap) do
        print('Event '..key..' has '..#value..' potential values')
        for _, v in ipairs(value) do
            print('Mapped '..key..' to '..v.value..' and chain '..v.chainId)
        end
    end
end

--- Request story termination
--- If artifact collection is active, waits for it to finish
--- @param reason string Reason for termination
function GraphStory:End(reason)
    if DEBUG then
        outputConsole("GraphStory:End - " .. (reason or "story completed"))
    end

    if self.Disposed then
        return
    end

    -- Phase 1: Immediate cleanup
    if self.StoryTimeoutTimer then
        self.StoryTimeoutTimer:destroy()
        self.StoryTimeoutTimer = nil
    end

    if self.CurrentEpisode then
        self.CurrentEpisode:Destroy()
    end

    self.Disposed = true

    -- Phase 2: Wait for collection, then terminate spectators
    if self.artifactManager and self.artifactManager:isScheduling() then
        if DEBUG then
            print("[GraphStory] Waiting for artifact collection to finish...")
        end

        -- Mark pending termination
        self.pendingTermination = {
            reason = reason or "story completed successfully"
        }

        -- Stop scheduling (will trigger completion callback)
        self.artifactManager:stopScheduledCollection()
    else
        -- No collection active, terminate immediately
        self:_completeTermination(reason or "story completed successfully")
    end
end

--- Complete termination after collection finishes
--- @param reason string Reason for termination (optional, uses pendingTermination if available)
function GraphStory:_completeTermination(reason)
    local terminationReason = reason
    if self.pendingTermination then
        terminationReason = self.pendingTermination.reason
        self.pendingTermination = nil
    end

    if DEBUG then
        print("[GraphStory] Completing termination: " .. terminationReason)
    end

    -- Terminate all spectators
    for _, spectator in ipairs(self.Spectators) do
        terminatePlayer(spectator, terminationReason)
    end
end