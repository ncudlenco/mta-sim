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
    o.allActions = {}
    o.metatable = {}
    o.episodeLinks = episodeLinks or {}
end)

function Location:getData(key)
    return self.metatable[key]
end

function Location:setData(key, value)
    self.metatable[key] = value
end

function Location:SpawnPlayerHere(player, spectate)
    self.isBusy = true
    player:setData('locationId', self.LocationId)
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

function Location:GetNextRandomValidAction(player)
    local story = GetStory(player)

    local previousAction = nil
    if #story.History[player:getData('id')] >= 1 then
        previousAction = story.History[player:getData('id')][#story.History]
    end

    local nextValidActions = Where(self.PossibleActions, function(x)
        return (x.NextLocation == self or not x.NextLocation.isBusy) and x ~= previousAction and All(x.Prerequisites, function(p)
            local li = LastIndexOf(self.History[player:getData('id')], p)
            local lic = LastIndexOf(self.History[player:getData('id')], p.ClosingAction)
            if DEBUG then
                outputConsole("Evaluating validity of action "..x.Description)
                outputConsole("Has prerequisite "..p.Description)
                if p.ClosingAction then
                    outputConsole("With closing action "..p.ClosingAction.Description)
                else
                    outputConsole("Doesn't have a closing action")
                end
                outputConsole("Prerequisite last index: "..li)
                if p.ClosingAction then
                    outputConsole("Closing action last index "..lic)
                end
                if p.ClosingAction and lic > li or li ~= -1 then
                    outputConsole("Marked as valid")
                else
                    outputConsole("Not valid")
                end
            end
            return p.ClosingAction and lic > li or li ~= -1
        end)
    end)
    if next(nextValidActions) == nil then
        if DEBUG then
            print("Location:GetNextValidAction - No more valid story actions found. Ending the current story")
            outputConsole("Location:GetNextValidAction - No more valid story actions found. Ending the current story")
        end
        lock = false
        return EndStory(player)
    end

    if #nextValidActions > 1 then
        table.remove(nextValidActions, 1)
    end

    if DEBUG_ACTIONS then
        if previousAction then
            str_act = "Actions: Previous action " .. string.sub(previousAction.ActionId, 1, 8) .. "-"
        else
            str_act = "Actions: no previous action - "
        end

        for i, action in ipairs(nextValidActions) do
            str_act = str_act .. string.sub(action.ActionId, 1, 8) .. " "
        end
    end

    return PickRandom(nextValidActions);
end

function Location:ProcessNextAction(player)
    local event = CURRENT_STORY.lastEvents[player:getData('id')]
    local location = CURRENT_STORY.lastLocations[player:getData('id')]
    local interactionProcessedMap = CURRENT_STORY.interactionProcessedMap
    local interactionPoiMap = CURRENT_STORY.interactionPoiMap

    if event == nil then return end

    local isMoveEvent = event.Action:lower() == 'move'

    local isInteractionStr = "false"
    if event.isInteraction then
        isInteractionStr = "true"
    end
    print(event.id..' isInteraction '..isInteractionStr)
    --if the event action has prerequisites then add them first if they are not already in the queue
    local eventAction = nil
    local actionsChain = {}

    if event.isInteraction then
        --set the actors one in front of the other in the same location...
        --create the interaction actions / locations
        local ped1 = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(p) return p:getData('id') == event.Entities[1] end)
        local ped2 = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(p) return p:getData('id') == event.Entities[2] end)

        --The interaction action will be executed only from the first actor
        if interactionProcessedMap[event.interactionRelation] then
            local wait = Wait { performer = ped1, nextLocation = location, targetItem = ped2, doNothing=true, time=10000000 }
            eventAction = wait
        else
            local wait = Wait { performer = ped1, nextLocation = location, targetItem = ped2, doNothing=false, time=10000000 }
            table.insert(actionsChain, wait)
            if event.Action == 'HandShake' then
                eventAction = HandShake {performer = ped1, nextLocation = location, targetPlayer = ped2, targetItem = ped2, time = random(6000, 15000)}
            elseif event.Action == 'Kiss' then
                eventAction = Kiss { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = ped2 }
            elseif event.Action == 'Hug' then
                eventAction = Hug { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = ped2 }
            elseif event.Action == 'Give' then
                local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o) return o.ObjectId == CURRENT_STORY.reverseObjectMap[event.interactionEvent.Entities[3]] end)
                if not object then
                    error('Could not find object to give from '..ped1:getData('id')..' to '..ped2:getData('id'))
                end
                print('PROCESSING INTERACTION Give from '..ped1:getData('id')..' to '..ped2:getData('id')..' object '..object:__tostring())
                eventAction = Give { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = object }
            elseif event.Action == 'INV-Give' or event.Action == 'Receive' then
                local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o) return o.ObjectId == CURRENT_STORY.reverseObjectMap[event.interactionEvent.Entities[3]] end)
                if not object then
                    error('Could not find object to give from '..ped1:getData('id')..' to '..ped2:getData('id'))
                end
                print('PROCESSING INTERACTION INV-Give from '..ped1:getData('id')..' to '..ped2:getData('id')..' object '..object.ObjectId..': '..object:__tostring())
                eventAction = Receive { performer = ped1, nextLocation = location, targetPlayer = ped2, TargetItem = object }
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
        eventAction = FirstOrDefault(location.allActions, function(action) return action.Name:lower() == event.Action:lower() end)
        if not eventAction then
            error('Event action could not be found '..event.Action)
        end
        -- local mandatoryPrevAction = eventAction
        -- local guard = 0
        -- while(mandatoryPrevAction and guard < 10) do
        --     print('Mandatory action:'.. mandatoryPrevAction.Name)

        --     mandatoryPrevAction = FirstOrDefault(location.allActions, function(action)
        --         print('Evaluating as prev action '.. action.ActionId .. ': '..action.Name)
        --         if (action.NextAction and not isArray(action.NextAction)) then
        --             print('Next action '.. action.NextAction.ActionId .. ': '..action.NextAction.Name)
        --         end
        --         return mandatoryPrevAction ~= action and action.Name ~= 'Move' and
        --             action.NextAction and ((isArray(action.NextAction) and Any(action.NextAction, function(na)
        --             return na == mandatoryPrevAction
        --         end))
        --         or (not isArray(action.NextAction) and action.NextAction == mandatoryPrevAction ))
        --     end)
        --     if mandatoryPrevAction then
        --         print('Mandatory prev action:'.. mandatoryPrevAction.Name)
        --         table.insert(actionsChain, 1, mandatoryPrevAction)
        --     end
        --     guard = guard + 1
        -- end
        -- if guard >= 10 then
        --     error('Infinite loop mandatoryPrevAction')
        -- end
    end
    if not isMoveEvent then
        print(eventAction.Name)
        table.insert(actionsChain, eventAction)
    end
--looking backward in the graph's chain of events to see if any actions were already processed is not necessary because
--in the steps below, we make sure that when we reach the first action from an enforced chain, then we process all their previous and following mandatory actions
    local nextEvent = FirstOrDefault(CURRENT_STORY.graph, function(evt) return evt.id == CURRENT_STORY.temporal[event.id].next end)
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

    --if this is the first event the player will be spawned in the required location
    --otherwise, if the player is not in the required location then add a move action to the required location (select it from allActions of the currentLocation)
    local nextLocation = nil
    if nextEvent then
        nextEvent.isInteraction = Any(CURRENT_STORY.Interactions, function(a) return a:lower() == nextEvent.Action:lower() end)
        if nextEvent.isInteraction then
            nextEvent.interactionRelation = FirstOrDefault(CURRENT_STORY.temporal[nextEvent.id].relations, function(rel) return CURRENT_STORY.temporal[rel].type == 'starts_with' end)
            nextEvent.interactionEvent = FirstOrDefault(CURRENT_STORY.graph, function(a)
                return a.id and CURRENT_STORY.temporal[a.id] and CURRENT_STORY.temporal[a.id].relations
                    and Any(CURRENT_STORY.temporal[a.id].relations, function(rel) return rel == nextEvent.interactionRelation end) end)
        end
        local strIsInteraction = 'false'
        if nextEvent.isInteraction then
            strIsInteraction = 'true'
        end
        print('Next event: '..nextEvent.id..' isInteraction '..strIsInteraction)

        local candidates = Where(CURRENT_STORY.CurrentEpisode.POI, function(poi)
            return
            (nextEvent.isInteraction and
                (
                    not interactionPoiMap[nextEvent.interactionRelation]
                    or
                    poi.LocationId == interactionPoiMap[nextEvent.interactionRelation]
                )
                or not nextEvent.isInteraction --and not poi.isBusy
            )
            and
            poi.Region and nextEvent.Location and (poi.Region.name:lower():find(nextEvent.Location[1]:lower()) and true or false )
            and
            (
                nextEvent.isInteraction
                or
                Any(poi.allActions, function(action)
                    return action.Name:lower() == nextEvent.Action:lower() --the location contains the required action for the next event
                    and (#nextEvent.Entities < 2 or
                    (action.TargetItem.ObjectId and #nextEvent.Entities > 1 and action.TargetItem.type == CURRENT_STORY.graph[nextEvent.Entities[2]].Properties.Type --action has a target an object of type x
                    and action.TargetItem.ObjectId == CURRENT_STORY.reverseObjectMap[nextEvent.Entities[2]]))
                end)
            )
        end)
        if DEBUG then
            for _,poi in ipairs(candidates) do
                local isBusyStr = 'false' if poi.isBusy then isBusy = 'true' end
                print('Candidate location '..poi.Description..' is busy '..isBusyStr)
            end
        end
        if All(candidates, function(poi) return poi.isBusy end) then
            nextLocation = PickRandom(candidates)
        else
            nextLocation = PickRandom(Where(candidates, function(poi) return not poi.isBusy end))
        end
        if not nextLocation then
            error('Could not find the next location '..nextEvent.id..': '..nextEvent.Location[1])
        elseif nextEvent.isInteraction then
            if interactionPoiMap[nextEvent.interactionRelation] == nextLocation.LocationId then
                --only subsequent actors reach this section (i.e. after a location was chosen for the interaction)
                local clone = Location(nextLocation.X - 0.7, nextLocation.Y - 0.7, nextLocation.Z, nextLocation.Angle, nextLocation.Interior, nextLocation.Description, nextLocation.Region, false)
                    --Î(this is an upward arrow) TODO: is it good, is it bad?
                clone.LocationId = nextLocation.LocationId
                clone.allActions = nextLocation.allActions --should include move actions here...
                clone.Episode = nextLocation.Episode
                nextLocation = clone
            end
            interactionPoiMap[nextEvent.interactionRelation] = nextLocation.LocationId
        end

        print('Next location '..nextLocation.Description)
    elseif #event.Location > 1 then
        local candidates = Where(CURRENT_STORY.CurrentEpisode.POI, function(poi)
            return
            poi.Region and event.Location[2] and (poi.Region.name:lower():find(event.Location[2]:lower()) and true or false )
        end)
        if DEBUG then
            for _,poi in ipairs(candidates) do
                local isBusyStr = 'false' if poi.isBusy then isBusy = 'true' end
                print('Candidate location '..poi.Description..' is busy '..isBusyStr)
            end
        end
        if All(candidates, function(poi) return poi.isBusy end) then
            nextLocation = PickRandom(candidates)
        else
            nextLocation = PickRandom(Where(candidates, function(poi) return not poi.isBusy end))
        end
    end
    if nextLocation and nextLocation ~= location then
        --if this is an interaction then create a move action with target the other player. handle internally inside the move action the positioning of the two players
        --
        print('Next action is in another location. Inserting a Move action from '..location.Description..' to '..nextLocation.Description..' in episode '..nextLocation.Episode.name)
        local moveAction = FirstOrDefault(location.allActions, function(action) return action.Name == 'Move' and action.TargetItem == nextLocation end)
        --actually I need to clone the move action to point to different coordinates inside the next location
        local clone = Move{performer = moveAction.Performer, targetItem = nextLocation, nextLocation = nextLocation, prerequisites = moveAction.Prerequisites, graphId = moveAction.graphId}
        clone.TargetItem = nextLocation
        table.insert(CURRENT_STORY.actionsQueues[player:getData('id')], clone)
    end

    CURRENT_STORY.lastEvents[player:getData('id')] = nextEvent
    CURRENT_STORY.lastLocations[player:getData('id')] = nextLocation

    print('Actions queue for actor '..player:getData('id'))
    for _, action in ipairs(CURRENT_STORY.actionsQueues[player:getData('id')]) do
        print(action.Name..' '..action:GetDynamicString())
    end
end

lock = false
function Location:GetNextValidAction(player)
    if CURRENT_STORY.Disposed then
        return EmptyAction({Performer = player})
    end

    --wait
    while lock do
        Timer(function()end, 500, 1)
    end
    lock = true

    if DEBUG then
        outputConsole("Location:GetNextValidAction")
    end
    if player == nil and DEBUG then
        outputConsole("Error Location:GetNextValidAction: Actor is null ")
    end
    local story = GetStory(player)
    if DEBUG and story == nil then
        outputConsole("Error Location:GetNextValidAction: story is null")
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
        lock = false
        return EndStory(player)
    end

    local next = nil
    if not LOAD_FROM_GRAPH then
        print('Get next random valid action')
        next = self:GetNextRandomValidAction(player)
    else
        local q = CURRENT_STORY.actionsQueues[player:getData('id')]
        if #q == 0 then self:ProcessNextAction(player) end
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
                        occupyingActor:setData('locationId', randomMove.NextLocation.LocationId)
                        randomMove.Performer = occupyingActor
                        randomMove:Apply()
                    else
                        local function wait()
                            local occupyingActor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(act) return act:getData('locationId') == next.NextLocation.LocationId end)
                            if (not occupyingActor) then
                                print('Occupying actor not found for location '..next.NextLocation.LocationId)
                            end
                            if next.NextLocation.isBusy and (not occupyingActor or not occupyingActor:getData('storyEnded')) then
                                player:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true)
                                Timer(wait, 5000, 1)
                            elseif not self.doNothing then
                                OnGlobalActionFinished(1000, player:getData('id'), player:getData('storyId'))
                            end
                        end
                        wait()
                        print('NextLocation is busy. Waiting')
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
        lock = false
        if LOAD_FROM_GRAPH then
            if Any(CURRENT_STORY.CurrentEpisode.peds, function(ped) return player:getData('id') ~= ped:getData('id') and not ped:getData('storyEnded') end) then
                if DEBUG then
                    outputConsole("Location:GetNextValidAction - waiting for the others to finish")
                end
                print("Location:GetNextValidAction - actor "..player:getData('id').." finished and is waiting for the others to finish")
                local unfinishedActors = Where(CURRENT_STORY.CurrentEpisode.peds, function(ped) return player:getData('id') ~= ped:getData('id') and not ped:getData('storyEnded') end)
                for i,p in ipairs(unfinishedActors) do
                    print(p:getData('id'))
                end
                --the episode is ended for the current actor, wait for all the other actors to finish
                player:setData('storyEnded', true)
                player:setAnimation("cop_ambient", "coplook_loop", 0, true, false, false, true)
                return nil
            end
        end
        return EndStory(player)
    else
        if DEBUG then
            outputConsole("Next action chosen: "..next.Description)
            print("Next action chosen: "..next.Description)
            print("Next action for actor "..player:getData('id').." chosen. Action: "..next.Description.." target location: "..next.NextLocation.Description.." in region: "..next.NextLocation.Region.name.." and episode: "..next.NextLocation.Region.Episode.name)
        end
        if next.NextLocation == self then
            table.insert(self.History[player:getData('id')], next)
        else
            self.History[player:getData('id')] = {}
            next.NextLocation.History[player:getData('id')] = {next}
            --the actor will change the location
            self.isBusy = false
            print("Location "..self.Description..' is not busy')
            next.NextLocation.isBusy = true
            print("Location "..next.NextLocation.Description..' is busy')
            player:setData('locationId', next.NextLocation.LocationId)

        end
    end
    lock = false
    next.Performer = player
    return next
end