Location = class(StoryLocationBase, function(o, x, y, z, angle, interior, description, region, compact, log, episodeLinks)
    StoryLocationBase.init(o, description, {})
    o.X = x
    o.Y = y
    o.Z = z
    o.Angle = angle
    o.Interior = interior
    o.History = {}
    o.Region = region
    o.isBusy = false
    if not compact then
        o.position = Vector3(x,y,z)
        o.rotation = Vector3(0,0,angle)
    else
        o.position = {x=x, y=y, z=z}
        o.rotation = {x=0, y=0, z=angle}
    end
    o.interactionsOnly = false
    o.allActions = {}
    o.metatable = {}
    o.episodeLinks = episodeLinks or {}
end)

function Location:getData(key)
    if key == nil then
        return nil
    end
    return self.metatable[key]
end

function Location:setData(key, value)
    self.metatable[key] = value
end

function Location:SpawnPlayerHere(player, spectate)
    if not spectate then
        self.isBusy = true
        print('[SpawnPlayerHere] '..player:getData('id')..' Location '..self.Description..' is set to busy')
        player:setData('locationId', self.LocationId)
    end
    local z = self.Z
    if spectate then
        z = self.Z + 3
    end
    player:spawn(self.X, self.Y, z, self.Angle, player.model, self.Interior)
    -- player:fadeCamera (true)
    if not STATIC_CAMERA and not spectate then
        player:setCameraTarget(player)
    end
    if DEBUG then
        outputConsole("Location:SpawnPlayerHere")
        print("Location:SpawnPlayerHere")
    end
end

function Location:Serialize(episode, relativePosition, _objects, _locations, _mainPOI, _saveMainPoiRelative)
    local objects = {}
    if _objects then
        objects = _objects
    end
    local locations = {}
    if _locations then
        locations = _locations
    end
    local serializedAllActions = {}
    for _, a in ipairs(self.allActions) do
        if DEBUG then
            print("Serialize:action "..a.id)
        end
        local serializedNextAction = nil
        if a.NextAction then
            if isArray(a.NextAction) then
                serializedNextAction = {}
                for _, na in ipairs(a.NextAction) do
                    table.insert(serializedNextAction, {id = na.id})
                end
            else
                serializedNextAction = { id = a.NextAction.id }
            end
        end
        local targetItemType = 'Object'
        local targetItemId = LastIndexOf(episode.Objects, a.TargetItem)
        if targetItemId < 0 then
            targetItemType = 'Location'
            targetItemId = LastIndexOf(episode.POI, a.TargetItem)
            if targetItemId < 0 then
                targetItemType = 'none'
            end
        end
        local closingAction = nil
        if a.ClosingAction then
            closingAction = {id = a.ClosingAction.id}
        end
        local serializedAction = {
            dynamicString = a:GetDynamicString(),
            id = a.id,
            nextAction = serializedNextAction,
            targetItem = {id = targetItemId, type = targetItemType},
            nextLocation = {id = LastIndexOf(episode.POI, a.NextLocation)},
            closingAction = closingAction,
            isClosingAction = a.IsClosingAction
        }

        if DEBUG then
            print("Serialize:serialized action "..serializedAction.dynamicString)
        end

        table.insert(serializedAllActions, serializedAction)
        local function processLocationDependency(location)
            if not location then
                return
            end
            if DEBUG then
                print("Serialize:process location relative "..location.id)
            end
            local locationCopy = {id = location.id or LastIndexOf(episode.POI, location)}
            --If next location is not myself and next location is not already processed in recursivity
            if
                locationCopy.id ~= LastIndexOf(episode.POI, self)
                and #Where(locations, function (x) return x.id == locationCopy.id end) == 0
                and (not _mainPOI or locationCopy.id ~= LastIndexOf(episode.POI, _mainPOI) )
            then
                local targetItemRelativePosition = Vector3(location.position.x, location.position.y, location.position.z) - relativePosition

                locationCopy = location:Serialize(episode, relativePosition, objects, locations, _mainPOI or self, true)
                -- locationCopy.X = targetItemRelativePosition.x
                -- locationCopy.Y = targetItemRelativePosition.y
                -- locationCopy.Z = targetItemRelativePosition.z
                --This is probably handled in recursivity already
                -- for _,v in ipairs(dependentObjects) do
                --     if #Where(objects, function (x) return x.id == v.id end) == 0 then
                --         table.insert(objects, v)
                --     end
                -- end
                -- for _,v in ipairs(dependentLocations) do
                --     if #Where(locations, function (x) return x.id == v.id end) == 0 then
                --         table.insert(locations, v)
                --     end
                -- end
                if #Where(locations, function (x) return x.id == locationCopy.id end) == 0 then
                    table.insert(locations, locationCopy)
                end
            end
        end
        if a.TargetItem and a.TargetItem.position and relativePosition then
            if targetItemType == 'Object' then
                if DEBUG then
                    outputConsole("Serialize:target object "..targetItemId)
                end

                local objectCopy = SampStoryObjectBase(a.TargetItem)
                local targetItemRelativePosition = Vector3(a.TargetItem.position.x, a.TargetItem.position.y, a.TargetItem.position.z) - relativePosition
                objectCopy.position = targetItemRelativePosition
                objectCopy.instance = nil
                objectCopy:UpdateData(true)
                objectCopy.id = targetItemId
                if #Where(objects, function (x) return x.id == objectCopy.id end) == 0 then
                    table.insert(objects, {
                        id = objectCopy.id,
                        dynamicString = objectCopy.dynamicString
                    })
                end
            elseif targetItemType == 'Location' then
                if DEBUG then
                    print("Serialize:target location "..targetItemId)
                end
                processLocationDependency(a.TargetItem)
            end
        end
        if relativePosition then
            if DEBUG then
                print("Serialize:process location relative")
            end
            processLocationDependency(a.NextLocation)
        end
    end

    local serializedPossibleActions = {}
    for _, a in ipairs(self.PossibleActions) do
        table.insert(serializedPossibleActions, {id = a.id})
    end

    local serializedMainPoi = {
        X = self.X,
        Y = self.Y,
        Z = self.Z,
        Angle = self.Angle,
        Interior = self.Interior,
        Description = self.Description,
        allActions = serializedAllActions,
        PossibleActions = serializedPossibleActions,
        id = LastIndexOf(episode.POI, self),
        episodeLinks = self.episodeLinks
    }
    if _saveMainPoiRelative then
        local targetItemRelativePosition = Vector3(self.X, self.Y, self.Z) - relativePosition
        serializedMainPoi.X = targetItemRelativePosition.x
        serializedMainPoi.Y = targetItemRelativePosition.y
        serializedMainPoi.Z = targetItemRelativePosition.z
    end
    return serializedMainPoi, objects, locations
end

function Location:GetMappedEventObjectId(eventObjectId, playerChainId)
    local mappedObjects = CURRENT_STORY.eventObjectMap[eventObjectId]
    if not mappedObjects then return nil end

    if type(mappedObjects) == "string" then
        return mappedObjects -- Handle "spawnable" case
    end

    if type(mappedObjects) == "table" and #mappedObjects > 0 then
        -- If player has a chain ID, prefer that chain
        if playerChainId then
            for _, tuple in ipairs(mappedObjects) do
                if tuple.chainId == playerChainId then
                    return tuple.value
                end
            end
        end
        
        -- Fallback: return the first available mapping if no chain match or no player chain ID
        if DEBUG then
            local chainIdStr = playerChainId and tostring(playerChainId) or "nil"
            print("[GetMappedEventObjectId] No chain match for object " .. eventObjectId .. " with player chain " .. chainIdStr .. ". Using fallback: " .. mappedObjects[1].value)
        end
        return mappedObjects[1].value
    end

    return nil
end

function Location:GetNextRandomValidAction(player)
    local story = GetStory(player)

    local previousChainOfActions = {}
    if #story.History[player:getData('id')] >= 1 then
        local i = #story.History
        local previousAction = story.History[player:getData('id')][#story.History]
        table.insert(previousChainOfActions, previousAction)
        if DEBUG then
            print("Prev action "..previousAction.Name)
        end

        --a1
        --a2 = a1.NextAction
        --...
        --an = an-1.NextAction
        while i-1 > 0 and not previousAction do
            local pprevAction = story.History[player:getData('id')][i-1]
            if previousAction.NextAction == pprevAction then
                previousAction = pprevAction
                table.insert(previousChainOfActions, pprevAction)
                if DEBUG then
                    print("Prev action "..previousAction.Name)
                end
            else
                previousAction = nil
            end
            i = i-1
        end
    end

    local nextValidActions = Where(self.PossibleActions, function(x)
        return (x.NextLocation == self or not x.NextLocation.isBusy) and All(previousChainOfActions, function(a) return a ~= x end)
            and All(x.Prerequisites, function(p)
                local startActionChainIndex = LastIndexOf(self.History[player:getData('id')], p, StoryActionBase.__eq)
                local endActionChainIndex = LastIndexOf(self.History[player:getData('id')], p.ClosingAction, StoryActionBase.__eq)
                if DEBUG then
                    print("Evaluating validity of action "..x.Description)
                    print("Has prerequisite "..p.Description)
                    if p.ClosingAction then
                        print("With closing action "..p.ClosingAction.Description)
                    else
                        print("Doesn't have a closing action")
                    end
                    print("Prerequisite last index: "..startActionChainIndex)
                    if p.ClosingAction then
                        print("Closing action last index "..endActionChainIndex)
                    end
                    if p.ClosingAction and endActionChainIndex > startActionChainIndex or startActionChainIndex ~= -1 then
                        print("Marked as valid")
                    else
                        print("Not valid")
                    end
                end
                return p.ClosingAction and endActionChainIndex > startActionChainIndex or startActionChainIndex ~= -1
            end)
    end)

    if #nextValidActions > 1 then
        table.remove(nextValidActions, 1)
    end

    return PickRandom(nextValidActions);
end

function InstantiateAction(event, player, location, object)
    if event.Action == 'Drink' then
        return Drink { performer = player, nextLocation = location, TargetItem = object }
    elseif event.Action == 'LookAtObject' then
        return LookAtObject { performer = player, nextLocation = location, TargetItem = object }
    end
    return nil
end


function Location:ProcessNextAction(player)
    local event = CURRENT_STORY.nextEvents[player:getData('id')]
    local location = CURRENT_STORY.nextLocations[player:getData('id')]
    local previousLocation = CURRENT_STORY.lastLocations[player:getData('id')]
    if not CURRENT_STORY.lastEvents[player:getData('id')] then
        CURRENT_STORY.lastEvents[player:getData('id')] = {}
    end

    local interactionProcessedMap = CURRENT_STORY.interactionProcessedMap
    local interactionPoiMap = CURRENT_STORY.interactionPoiMap

    if DEBUG_PROCESSACTIONS then
        for _, poi in ipairs(CURRENT_STORY.CurrentEpisode.POI) do
            local isBusyString = 'false'
            if poi.isBusy then
                isBusyString = 'true'
            end
                print(poi.LocationId..' '..poi.Description..' '..isBusyString)
        end
    end
    if event == nil then return {isStartingEvent = false} end

    if DEBUG then
        print(player:getData('id')..' Processing next event '..event.id..' '..event.Action..' in location '..location.Description)
    end
    local lastEvents = CURRENT_STORY.lastEvents[player:getData('id')]
    if not event.isStartingEvent and (#lastEvents == 0 or event.id ~= lastEvents[#lastEvents]) then
        table.insert(CURRENT_STORY.lastEvents[player:getData('id')], event)
    end

    local isMoveEvent = event.Action:lower() == 'move'
    local actionsChain = {}

    if previousLocation and location and previousLocation ~= location then
        --if this is an interaction then create a move action with target the other player. handle internally inside the move action the positioning of the two players
        --
        print('Next action is in another location. Inserting a Move action from '..previousLocation.Description..' to '..location.Description..' in episode '..location.Episode.name)
        local moveAction = FirstOrDefault(previousLocation.allActions, function(action) return action.Name == 'Move' and action.TargetItem == location end)
        --actually I need to clone the move action to point to different coordinates inside the next location
        local clone = Move{performer = moveAction.Performer, targetItem = location, nextLocation = location, prerequisites = moveAction.Prerequisites, graphId = moveAction.graphId}
        clone.TargetItem = location
        table.insert(CURRENT_STORY.actionsQueues[player:getData('id')], clone)
    end

    if not event.isStartingEvent then
        local isInteractionStr = "false"
        if event.isInteraction then
            isInteractionStr = "true"
        end
        print(event.id..' isInteraction '..isInteractionStr)
        --if the event action has prerequisites then add them first if they are not already in the queue
        local eventAction = nil

        -- First, map the current event to the action that will be executed in the current location (e.g. based on the event action name). For interactions we need to create a wait action.
        if event.isInteraction then
            --set the actors one in front of the other in the same location...
            --create the interaction actions / locations
            local ped1 = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(p) return p:getData('id') == event.Entities[1] end)
            local ped2 = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(p) return p:getData('id') == event.Entities[2] end)

            --The interaction action will be executed only from the first actor
            if interactionProcessedMap[event.interactionRelation] then
                local wait = Wait { performer = ped1, nextLocation = location, targetItem = ped2, targetInteraction = event.interactionRelation, doNothing=true, time=10000000 }
                eventAction = wait
            else
                local wait = Wait { performer = ped1, nextLocation = location, targetItem = ped2, targetInteraction = event.interactionRelation, doNothing=false, time=10000000 }
                table.insert(actionsChain, wait)
                if event.Action == 'HandShake' or event.Action == "Handshake" then
                    eventAction = HandShake {performer = ped1, nextLocation = location, targetPlayer = ped2, targetItem = ped2, time = random(6000, 15000)}
                elseif event.Action == 'Kiss' then
                    eventAction = Kiss { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = ped2 }
                elseif event.Action == 'Hug' then
                    eventAction = Hug { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = ped2 }
                elseif event.Action == 'Give' then
                    local pickedUpObjectId = ped1:getData('pickedObjects')[1][1]
                    local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o) return o.ObjectId == pickedUpObjectId end)
                    if not object then
                        error('Could not find object to give from '..ped1:getData('id')..' to '..ped2:getData('id'))
                    end
                    print('PROCESSING INTERACTION Give from '..ped1:getData('id')..' to '..ped2:getData('id')..' object '..object:__tostring())
                    eventAction = Give { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = object }
                elseif event.Action == 'INV-Give' or event.Action == 'Receive' then
                    print('PROCESSING INTERACTION INV-Give from '..ped1:getData('id')..' to '..ped2:getData('id')..' object: whatever object has or will have the other actor')
                    eventAction = Receive { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = nil }
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
        elseif not isMoveEvent then
            local pickedUpObjects = player:getData('pickedObjects')
            local playerChainId = player:getData('mappedChainId')
            local isActionWithObjectCurrentlyPicked = event and #event.Entities > 1 and #pickedUpObjects > 0 and #pickedUpObjects[1] > 0 and self:GetMappedEventObjectId(event.Entities[2], playerChainId) == pickedUpObjects[1][1]

            if isActionWithObjectCurrentlyPicked then
                local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o) return o.ObjectId == pickedUpObjects[1][1] end)
                eventAction = InstantiateAction(event, player, location, object)
            end
            if eventAction == nil and event.Action == 'LookAtObject' then
                local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o) return o.ObjectId == self:GetMappedEventObjectId(event.Entities[2], playerChainId) end)
                eventAction = InstantiateAction(event, player, location, object)
            end
            if eventAction == nil then
                eventAction = FirstOrDefault(location.allActions, function(action) return action.Name:lower() == event.Action:lower() end)
            end
            if not eventAction then
                error('Event action could not be found '..event.Action)
            end
        end
        if not isMoveEvent then
            print(eventAction.Name)
            table.insert(actionsChain, eventAction)
        end
    end

--looking backward in the graph's chain of events to see if any actions were already processed is not necessary because
--in the steps below, we make sure that when we reach the first action from an enforced chain, then we process all their previous and following mandatory actions
    local nextEvent;
    if event.isStartingEvent then
        nextEvent = event
    else
        print(player:getData('id')..' current event '..event.Action)
        nextEvent = FirstOrDefault(CURRENT_STORY.graph, function(evt) return evt.id == CURRENT_STORY:GetNextEvent(event.id, player:getData('id')) end)
        if nextEvent then
            print(player:getData('id')..' next event '..nextEvent.Action)
        end
    end

    if not isMoveEvent then
        -- local nextMandatoryAction = eventAction.NextAction
        -- while (nextMandatoryAction) do
        --     --if the action has mandatory closing actions then add them if they are not already in the graph next actions
        --     if  nextEvent
        --         and (isArray(nextMandatoryAction)
        --         and Any(nextMandatoryAction, function(action)
        --             return action.Name:lower() == nextEvent.Action:lower()--action.location is the same as the event.next.location (technically, in a chain the location doesn't change, except when it does (Dance)...)
        --         end)
        --         or (not isArray(nextMandatoryAction) and nextMandatoryAction.Name:lower() == nextEvent.Action:lower())
        --         )
        --         and
        --         (eventAction.NextLocation.Region.name:lower():find(nextEvent.Location[1]:lower()) and true or false)
        --     then
        --         if isArray(nextMandatoryAction) then
        --             nextMandatoryAction = FirstOrDefault(nextMandatoryAction, function(action) return action.Name:lower() == nextEvent.Action:lower() end)
        --         end
        --         --if the action is set in the next future event in the same location, skip the processing of the next future event
        --         nextEvent = FirstOrDefault(CURRENT_STORY.graph, function(evt) return evt.id == CURRENT_STORY.temporal[nextEvent.id].next end)
        --     end

        --     if isArray(nextMandatoryAction) then
        --         nextMandatoryAction = PickRandom(nextMandatoryAction)
        --     end
        --     print(nextMandatoryAction.Name)
        --     table.insert(actionsChain, nextMandatoryAction)
        --     nextMandatoryAction = nextMandatoryAction.NextAction
        -- end
        --add the required actions

        for _, action in ipairs(actionsChain) do
            table.insert(CURRENT_STORY.actionsQueues[player:getData('id')], action)
        end
    end

    local isnextEventMove = nextEvent and nextEvent.Action:lower() == 'move'

    --if this is the first event the player will be spawned in the required location
    --otherwise, if the player is not in the required location then add a move action to the required location (select it from allActions of the currentLocation)
    local nextLocation = nil
    if nextEvent then
        nextEvent.isInteraction = Any(CURRENT_STORY.Interactions, function(a) return a:lower() == nextEvent.Action:lower() end)
        if nextEvent.isInteraction then
            nextEvent.interactionRelation = FirstOrDefault(CURRENT_STORY.temporal[nextEvent.id].relations, function(rel) return CURRENT_STORY.temporal[rel].type == 'starts_with' or CURRENT_STORY.temporal[rel].type == 'same_time' end)
            nextEvent.interactionEvent = FirstOrDefault(CURRENT_STORY.graph, function(a)
                return a.id and CURRENT_STORY.temporal[a.id] and CURRENT_STORY.temporal[a.id].relations
                    and Any(CURRENT_STORY.temporal[a.id].relations, function(rel) return rel == nextEvent.interactionRelation end) end)
        end
        local strIsInteraction = 'false'
        if nextEvent.isInteraction then
            strIsInteraction = 'true'
        end

        local isActionWithObjectThatWillBeReceived = event and nextEvent and event.Action == 'INV-Give' and #nextEvent.Entities > 1 and nextEvent.Entities[2] == event.Entities[3]
        local pickedUpObjectId = nil
        local pickedUpObjects = player:getData('pickedObjects')
        if #pickedUpObjects > 0 and #pickedUpObjects[1] > 0 then
            pickedUpObjectId = pickedUpObjects[1][1]
            if DEBUG then
                print("Currently picked up object: "..pickedUpObjects[1][1])
            end
        end
        -- PROBLEM: the event object map has to be computed before the evaluation of the location candidates because the location of objects might chage during the simulation.
        -- in addition, some locations might be mapped
        local playerChainId = player:getData('mappedChainId')
        if event and event.Action == 'PickUp' and event.Entities and #event.Entities > 1 then
            pickedUpObjectId = self:GetMappedEventObjectId(event.Entities[2], playerChainId)
        end
        if DEBUG and self:GetMappedEventObjectId(nextEvent.Entities[2], playerChainId) then
            print("Mapped object for next event "..self:GetMappedEventObjectId(nextEvent.Entities[2], playerChainId))
        end
        local isActionWithObjectCurrentlyPicked = nextEvent and #nextEvent.Entities > 1 and pickedUpObjectId ~= nil and self:GetMappedEventObjectId(nextEvent.Entities[2], playerChainId) == pickedUpObjectId
        local isActionWithPickedUpObject = isActionWithObjectThatWillBeReceived or isActionWithObjectCurrentlyPicked

        print('Next event: '..nextEvent.id..' isInteraction '..strIsInteraction..' isActionWithPickedUpObject '..BoolToStr(isActionWithPickedUpObject))
        local candidates;
        if CURRENT_STORY.poiMap and CURRENT_STORY.poiMap[nextEvent.id] then
            print("Assessing if there are any actual location candidates with id "..nextEvent.id)
            -- if the event involves an object and the potential pois are mapped to the event id then use them as candidates
            -- a problem with this is that there may be multiple valid objects and you have to choose one that was already chosen by a different actor (e.g. sit down on the same sofa)
            local mappedLocations = Where(CURRENT_STORY.CurrentEpisode.POI, function(poi)
                if CURRENT_STORY.poiMap[nextEvent.id] then
                    for _, mappedTuple in ipairs(CURRENT_STORY.poiMap[nextEvent.id]) do
                        if poi.LocationId == mappedTuple.value then
                            poi:setData("mappedChainId_"..nextEvent.id, mappedTuple.chainId)
                            return true
                        end
                    end
                end
                return false
            end)
            if DEBUG and DEBUG_LOCATION_CANDIDATES then
                -- Print all mapped locations
                for _,mappedLocation in ipairs(mappedLocations) do
                    print('Mapped location '..mappedLocation.Description..' for event '..nextEvent.id .. '. Skipping searching for additional candidates.')
                end
            end
            if player:getData('mappedChainId') ~= nil then
                candidates = Where(mappedLocations, function(poi) return poi:getData("mappedChainId_"..nextEvent.id) == player:getData('mappedChainId') end)
                if #candidates == 0 then
                    print("WARNING: No locations found for player's assigned chain ID " .. player:getData('mappedChainId')..'. Falling back to any mapped locations.')
                    candidates = mappedLocations -- Fallback to any available
                end
            else
                candidates = mappedLocations
            end
        else
            -- Find candidates for locations that are not mapped
            candidates = Where(CURRENT_STORY.CurrentEpisode.POI, function(poi)
                if DEBUG and DEBUG_LOCATION_CANDIDATES then
                    print('Checking candidate location '..poi.Description)
                end
                local isValidInteractionPoiOrNotInteractionAtAll = nextEvent.isInteraction and
                    poi.interactionsOnly and
                    (
                        not interactionPoiMap[nextEvent.interactionRelation]
                        or
                        poi.LocationId == interactionPoiMap[nextEvent.interactionRelation]
                    )
                    or not nextEvent.isInteraction --and not poi.isBusy
                local nextEventTargetLocation = isnextEventMove and nextEvent.Location[2] or nextEvent.Location[1]
                local isValidRegion = poi.Region and nextEvent.Location and (poi.Region.name:lower():find(nextEventTargetLocation:lower()) and true or false)
                local restrictInteractionsToInteractionPois = nextEvent.isInteraction and poi.interactionsOnly
                local locationContainsObjectOfEvent = Any(poi.allActions, function(action)
                    return action.Name:lower() == nextEvent.Action:lower() --the location contains the required action for the next event
                    and (
                        #nextEvent.Entities < 2 or
                        (action.TargetItem.ObjectId and #nextEvent.Entities > 1 and
                            (
                                action.TargetItem and action.TargetItem.type == CURRENT_STORY.graph[nextEvent.Entities[2]].Properties.Type
                            ) --action has a target an object of type x
                            and (self:GetMappedEventObjectId(nextEvent.Entities[2], playerChainId) == 'spawnable' or action.TargetItem.ObjectId == self:GetMappedEventObjectId(nextEvent.Entities[2], playerChainId))
                        )
                    )
                end)

                if DEBUG and DEBUG_LOCATION_CANDIDATES then
                    print('isValidInteractionPoiOrNotInteractionAtAll '..BoolToStr(isValidInteractionPoiOrNotInteractionAtAll)
                        ..' and isValidRegion '..BoolToStr(isValidRegion)
                        ..' and (restrictInteractionsToInteractionPois '..BoolToStr(restrictInteractionsToInteractionPois)
                        ..' or locationContainsObjectOfEvent '..BoolToStr(locationContainsObjectOfEvent)..')')
                end

                return
                    isValidInteractionPoiOrNotInteractionAtAll
                    and
                    isValidRegion
                    and
                    (
                        restrictInteractionsToInteractionPois
                        or
                        locationContainsObjectOfEvent
                    )
            end)
        end
        if not nextEvent.isInteraction and #candidates == 0 and isActionWithPickedUpObject then
            candidates = Where(CURRENT_STORY.CurrentEpisode.POI, function(poi)
                return poi.Region and nextEvent.Location and (poi.Region.name:lower():find(nextEvent.Location[1]:lower()) and true or false )
            end)
        end
        if nextEvent.Action == 'LookAtObject' then
            candidates = {
                location
            }
        end
        if DEBUG then
            for _,poi in ipairs(candidates) do
                local isBusyStr = 'false'
                if poi.isBusy then isBusyStr = 'true' end
                print('Candidate location '..poi.Description..' is busy '..isBusyStr)
            end
        end
        -- if Any(CURRENT_STORY.CurrentEpisode.peds, function(p) return p:getData('waitingFor') == nextLocation.LocationId end) then
        --     --Move randomly if someone else is waiting on my location to be vacated but I am occupying it with my waiting around...
        --     local randomMove = PickRandom(Where(self.NextLocation.PossibleActions, function(a) return a.Name == 'Move' and not a.NextLocation.isBusy end))
        --     randomMove.NextLocation.isBusy = true
        --     self.Performer:setData('locationId', randomMove.NextLocation.LocationId)
        --     randomMove.Performer = self.Performer
        --     randomMove:Apply()
        -- end
        if #candidates == 0 then
            -- No candidates found, use current location as fallback
            nextLocation = location
            print('WARNING: No location candidates found for event '..nextEvent.id..'. Using current location.')
        elseif All(candidates, function(poi) return poi ~= location and poi.isBusy end) then
            nextLocation = PickRandom(candidates)
        else
            nextLocation = PickRandom(Where(candidates, function(poi) return not poi.isBusy end))
        end

        -- If the current location is among the next candidates, choose this one. This helps in case there are multiple actions in the same location: e.g. SitDown, PickUp, Eat, GetUp (on different chairs)
        -- I would like to execute all these actions on the same chair (same location)
        if FirstOrDefault(candidates, function(poi) return poi == location end)
        --     and not Any(CURRENT_STORY.CurrentEpisode.peds, function(p) return p:getData('waitingFor') == poi.LocationId end) end)
        then
            nextLocation = FirstOrDefault(candidates, function(poi) return poi == location end)
        end
        if not nextLocation then
            print('Could not find the next location '..nextEvent.id..': '..nextEvent.Location[1])
            -- Emergency fallback: use current location if no valid candidate found
            nextLocation = location
            print('WARNING: Using current location '..location.Description..' as fallback for event '..nextEvent.id)
        elseif nextEvent.isInteraction then
            if interactionPoiMap[nextEvent.interactionRelation] == nextLocation.LocationId then
                --only subsequent actors reach this section (i.e. after a location was chosen for the interaction)
                local clone = Location(nextLocation.X - 0.7, nextLocation.Y - 0.7, nextLocation.Z, nextLocation.Angle, nextLocation.Interior, nextLocation.Description, nextLocation.Region, false)
                    --Î(this is an upward arrow) TODO: is it good, is it bad?
                clone.LocationId = nextLocation.LocationId
                clone.allActions = nextLocation.allActions --should include move actions here...
                clone.Episode = nextLocation.Episode
                nextLocation = clone
                print("Set nextLocation to a clone of the next location position, shifted by 0.7 "..nextLocation.Description)
            end
            interactionPoiMap[nextEvent.interactionRelation] = nextLocation.LocationId
        end

        print('Next location '..nextLocation.Description.." "..nextLocation.LocationId)
        print("Current location "..location.Description.." "..location.LocationId)

        -- Set the player's chain ID based on the selected location
        if nextLocation and player:getData('mappedChainId') == nil then
            local chainId = nextLocation:getData("mappedChainId_"..nextEvent.id)
            if chainId then
                player:setData('mappedChainId', chainId)
                print("Player " .. player:getData('id') .. " assigned to chain ID: " .. chainId .. " for event " .. nextEvent.id)
            elseif DEBUG then
                print("No chain ID found for location " .. nextLocation.Description .. " and event " .. nextEvent.id)
            end
        elseif DEBUG and player:getData('mappedChainId') then
            print("Player " .. player:getData('id') .. " already has chain ID: " .. player:getData('mappedChainId'))
        end
    elseif #event.Location > 1 then
        local candidates = Where(CURRENT_STORY.CurrentEpisode.POI, function(poi)
            return
            poi.Region and event.Location[2] and (poi.Region.name:lower():find(event.Location[2]:lower()) and true or false )
        end)
        if DEBUG then
            for _,poi in ipairs(candidates) do
                local isBusyStr = 'false'
                if poi.isBusy then isBusyStr = 'true' end
                print('Candidate location '..poi.Description..' is busy '..isBusyStr)
            end
        end
        if All(candidates, function(poi) return poi.isBusy end) then
            nextLocation = PickRandom(candidates)
        else
            nextLocation = PickRandom(Where(candidates, function(poi) return not poi.isBusy end))
        end
    end

    CURRENT_STORY.nextEvents[player:getData('id')] = nextEvent
    CURRENT_STORY.nextLocations[player:getData('id')] = nextLocation
    CURRENT_STORY.lastLocations[player:getData('id')] = location

    print('Actions queue for actor '..player:getData('id'))
    for _, action in ipairs(CURRENT_STORY.actionsQueues[player:getData('id')]) do
        print(action.Name..' '..action:GetDynamicString())
    end

    if event.isStartingEvent then
        event.isStartingEvent = false
        return {isStartingEvent = true}
    end
    return {isStartingEvent = false}
end

lock = false
function Location:GetNextValidAction(player)
    if CURRENT_STORY and CURRENT_STORY.Disposed then
        return EmptyAction({Performer = player})
    end

    --wait
    while lock do
        Timer(function()end, 500, 1)
    end
    lock = true

    if DEBUG then
        print("Location:GetNextValidAction")
    end
    if player == nil and DEBUG then
        print("Error Location:GetNextValidAction: Actor is null ")
    end
    local story = GetStory(player)
    if DEBUG and story == nil then
        print("Error Location:GetNextValidAction: story is null")
    end
    if not self.History then
        self.History = {}
    end
    if not self.History[player:getData('id')] then
        self.History[player:getData('id')] = {}
    end
    if not story.History then
        story.History = {}
    end
    if not story.History[player:getData('id')] then
        story.History[player:getData('id')] = {}
    end
    print('Story actions nr '..#(story.History[player:getData('id')]))
    if #(story.History[player:getData('id')]) >= story.MaxActions then
        if DEBUG then
            outputConsole("Location:GetNextValidAction - max story actions reached. Ending the current story")
        end
        table.insert(CURRENT_STORY.lastEvents[player:getData('id')], {id = "$@!end_story!@$"})
        lock = false
        return EndStory(player)
    end

    local next = nil
    if not LOAD_FROM_GRAPH then
        print('Get next random valid action')
        next = self:GetNextRandomValidAction(player)
    else
        local q = CURRENT_STORY.actionsQueues[player:getData('id')]
        local isStartingEvent = false;
        if #q == 0 then isStartingEvent = self:ProcessNextAction(player).isStartingEvent end
        if #q == 0 and isStartingEvent then
            --Adds the initial actions to the queue and finds the next event
            self:ProcessNextAction(player)
        end
        if #q > 0 then
            next = q[1]
            local sssss = '?????'
            if next.Name then
                sssss = next.Name
            end
            print('Next action is '..sssss)
            if next and next.Name == 'Move' then
                print('Next action is to move')
                if next.NextLocation and next.NextLocation.isBusy and player:getData('locationId') ~= next.NextLocation.LocationId then
                    local occupyingActor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(act) return act:getData('locationId') == next.NextLocation.LocationId end)
                    if occupyingActor and occupyingActor:getData('storyEnded') then
                        --the actor occupying the location finished his mandatory tasks. move him around randomly to clear the location
                        local randomMove = PickRandom(Where(next.NextLocation.PossibleActions, function(a) return a.Name == 'Move' and not a.NextLocation.isBusy end))
                        randomMove.NextLocation.isBusy = true
                        print('[Location.GetNextValidAction] Move randomly occupying actor '..occupyingActor:getData('id')..'. Location ..'..randomMove.NextLocation.Description..' is set to busy')
                        occupyingActor:setData('locationId', randomMove.NextLocation.LocationId)
                        randomMove.Performer = occupyingActor
                        randomMove:Apply()
                    else
                        local function wait()
                            local occupyingActor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(act) return act:getData('locationId') == next.NextLocation.LocationId end)
                            if (not occupyingActor) then
                                print('Occupying actor not found for location '..next.NextLocation.LocationId..' ('..next.Description..')')
                            end
                            if next.NextLocation.isBusy and (not occupyingActor or not occupyingActor:getData('storyEnded')) then
                                player:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true)
                                if player:getData('requestPause') then
                                    player:setData('requestPause', false)
                                    player:setData('paused', true)
                                end
                                Timer(wait, 5000, 1)
                            elseif not self.doNothing then
                                player:setData('waitingFor',nil)
                                OnGlobalActionFinished(1000, player:getData('id'), player:getData('storyId'))
                            end
                        end
                        player:setData('waitingFor', next.NextLocation.LocationId)
                        print('NextLocation is busy. Waiting')
                        wait()
                        lock = false
                        return nil
                    end
                end
            end
            --if the current action is move and move.nextLocation is Busy then wait
            table.remove(q, 1)
        end
    end

    if not next then
        if DEBUG then
            outputConsole("Location:GetNextValidAction - next action was null. Ending the current player's story")
            print("Location:GetNextValidAction - next action was null. Ending the current player's story")
        end
        table.insert(CURRENT_STORY.lastEvents[player:getData('id')], {id = "$@!end_story!@$"})
        lock = false
        return EndStory(player)
    else
        if DEBUG then
            outputConsole("Next action chosen: "..next.Description)
            print("Next action chosen: "..next.Description .." "..next.Name)
            if not next.NextLocation then
                print("Error: Next action had a null next location!")
            else
                print("Next action for actor "..player:getData('id').." chosen. Action: "..next.Description.." target location: "..next.NextLocation.Description.." in region: "..next.NextLocation.Region.name.." and episode: "..next.NextLocation.Region.Episode.name)
            end
        end
        if next.NextLocation == self then
            if DEBUG then
                print("Add next action to history "..next.Name.." - "..next.Description)
            end
            table.insert(self.History[player:getData('id')], next)
        else
            self.History[player:getData('id')] = {}
            next.NextLocation.History[player:getData('id')] = {next}
            --the actor will change the location
            self.isBusy = false
            print(player:getData('id').."Location "..self.Description..' is not busy')
            next.NextLocation.isBusy = true
            print(player:getData('id').."Location "..next.NextLocation.Description..' is busy')
            player:setData('locationId', next.NextLocation.LocationId)

        end
    end
    lock = false
    next.Performer = player
    return next
end