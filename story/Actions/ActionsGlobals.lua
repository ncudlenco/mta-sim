FIRST_ACTOR = nil
SECOND_ACTOR = nil
PERFORM_MULTI_ACTION = nil
PERFORM_MULTI_ACTION_FIRST_ACTOR = nil 
MULTI_ACTION_DONE = true

function OnGlobalActionFinished(delay, playerId, storyId, callback, destroyedItem)
    --TODO: log events here, update the time taken inside the timer
    local actionStartTime = CURRENT_STORY.Logger:GetElapsedTime()
    Timer(function(playerId, storyId)
        local story = CURRENT_STORY
        local lastAction = story.History[playerId][#story.History[playerId]]
        if lastAction then
            --TODO: log events here
            local target = nil
            if lastAction.TargetItem then
                target = {
                    id = lastAction.TargetItem.ObjectId or lastAction.TargetItem.LocationId or lastAction.TargetItem:getData('id'),
                    type = lastAction.TargetItem.StoryItemType,
                    relativePosition = lastAction.TargetItem:getData('relativePosition')
                }
            else
                target = {
                    id = nil,
                    type = nil,
                    relativePosition = nil
                }
            end
            
            if lastAction.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
                local event = {
                    Actor = { 
                        id = lastAction.Performer:getData('id'), 
                        relativePosition = lastAction.Performer:getData('relativePosition') 
                    },
                    Action = lastAction.Description,
                    Location = lastAction.Performer:getData('currentRegion'),
                    Start = actionStartTime,
                    End = CURRENT_STORY.Logger:GetElapsedTime(),
                    Target = target
                }
                table.insert(GRAPH.Events, event)
            end
        end
        if DEBUG then
            outputConsole("GlobalAction:Apply - getting next valid action")
        end
        if callback then
            callback(playerId, storyId)
        end
        
        -- get the current peds of the episode
        local peds = story.CurrentEpisode.peds
        local nextAction = nil

        -- if there are multiple actors select with a random prob a second actor to do a multi-agent actions
        if not MULTI_ACTION_DONE and #peds > 1 and lastAction.isMove then
            if #peds> 1 and random(1, 100) < 1000 and SECOND_ACTOR == nil then
                -- pick another actor - ped2
                local ped1 = lastAction.Performer
                local ped2 = PickRandom(peds)

                if ped2:getData("id") == ped1:getData("id") then
                    for i, v in ipairs(peds) do
                        if v:getData("id") == ped1:getData("id") then
                            if i > 1 then
                                ped2 = peds[i - 1]
                            else
                                ped2 = peds[i + 1]
                            end
                        end
                    end
                end
                
                -- save it for futher usage
                FIRST_ACTOR = ped1
                SECOND_ACTOR = ped2

                -- save the location of the current agent
                local ped1Location = Location(ped1.position.x, ped1.position.y, ped1.position.z, 90, story.CurrentEpisode.InteriorId, "")

                -- make the current actor wait for the second actor to come
                local waitPed1 = Wait { performer = ped1, nextLocation = ped1Location, targetItem = ped1Location, graphId = story.CurrentEpisode.graphId, time=10000000 }
                table.insert(ped1Location.PossibleActions, waitPed1)
                waitPed1:Apply()

                -- TODO: perform the multi-agent action, reset the variables (SECOND_ACTOR and FIRST_ACTOR_LOCATION), select a better node

            -- if this is the second actor, then move to the first actor
            elseif lastAction.Performer:getData("id") == SECOND_ACTOR:getData("id") and PERFORM_MULTI_ACTION == nil then
                local ped2Location = nil

                if FIRST_ACTOR.rotation.z < 180 then
                    ped2Location = Location(FIRST_ACTOR.position.x - 0.5, FIRST_ACTOR.position.y - 0.5, FIRST_ACTOR.position.z, 270, story.CurrentEpisode.InteriorId, "")
                else
                    ped2Location = Location(FIRST_ACTOR.position.x + 0.5, FIRST_ACTOR.position.y + 0.5, FIRST_ACTOR.position.z, 270, story.CurrentEpisode.InteriorId, "")
                end

                local movePed2 = Move { performer = SECOND_ACTOR, nextLocation = ped2Location, targetItem = ped2Location, graphId = story.CurrentEpisode.graphId }
                table.insert(ped2Location.PossibleActions, movePed2)
                movePed2:Apply()

                PERFORM_MULTI_ACTION = true
            -- else perform the normal action
            elseif lastAction.Performer:getData("id") == SECOND_ACTOR:getData("id") and PERFORM_MULTI_ACTION then
                local ped1Location = Location(FIRST_ACTOR.position.x, FIRST_ACTOR.position.y, FIRST_ACTOR.position.z, 90, story.CurrentEpisode.InteriorId, "")
                local ped2Location = nil

                if FIRST_ACTOR.rotation.z < 180 then
                    ped2Location = Location(FIRST_ACTOR.position.x - 0.5, FIRST_ACTOR.position.y - 0.5, FIRST_ACTOR.position.z, 270, story.CurrentEpisode.InteriorId, "")
                    FIRST_ACTOR:setRotation(0, 0, 135)
                    SECOND_ACTOR:setRotation(0, 0, 315)
                else
                    ped2Location = Location(FIRST_ACTOR.position.x + 0.5, FIRST_ACTOR.position.y + 0.5, FIRST_ACTOR.position.z, 270, story.CurrentEpisode.InteriorId, "")
                    FIRST_ACTOR:setRotation(0, 0, 315)
                    SECOND_ACTOR:setRotation(0, 0, 135)
                end

                local multiActionType = PickRandom({"talk", "hug", "kiss", "laugh"})
                local multiActionPed1 = nil
                local multiActionPed2 = nil

                if multiActionType == "talk" then
                    local time = random(6000, 15000)
                    multiActionPed1 = Talk { performer = FIRST_ACTOR, nextLocation = ped1Location, targetPlayer = SECOND_ACTOR, TargetItem = SECOND_ACTOR, graphId = story.CurrentEpisode.graphId, time = time}
                    multiActionPed2 = Talk { performer = SECOND_ACTOR, nextLocation = ped2Location, targetPlayer = FIRST_ACTOR, TargetItem = FIRST_ACTOR, graphId = story.CurrentEpisode.graphId, time = time}
                elseif multiActionType == "kiss" then
                    multiActionPed1 = Kiss { performer = FIRST_ACTOR, nextLocation = ped1Location, targetPlayer = SECOND_ACTOR, TargetItem = SECOND_ACTOR, graphId = story.CurrentEpisode.graphId}
                    multiActionPed2 = Kiss { performer = SECOND_ACTOR, nextLocation = ped2Location, targetPlayer = FIRST_ACTOR, TargetItem = FIRST_ACTOR, graphId = story.CurrentEpisode.graphId}
                elseif multiActionType == "hug" then
                    multiActionPed1 = Hug { performer = FIRST_ACTOR, nextLocation = ped1Location, targetPlayer = SECOND_ACTOR, TargetItem = SECOND_ACTOR, graphId = story.CurrentEpisode.graphId}
                    multiActionPed2 = Hug { performer = SECOND_ACTOR, nextLocation = ped2Location, targetPlayer = FIRST_ACTOR, TargetItem = FIRST_ACTOR, graphId = story.CurrentEpisode.graphId}
                elseif multiActionType == "laugh" then
                    local jokeTarget = PickRandom({FIRST_ACTOR, SECOND_ACTOR})
                    multiActionPed1 = Laugh { performer = FIRST_ACTOR, nextLocation = ped1Location, targetPlayer = jokeTarget, TargetItem = jokeTarget, graphId = story.CurrentEpisode.graphId}
                    multiActionPed2 = Laugh { performer = SECOND_ACTOR, nextLocation = ped2Location, targetPlayer = jokeTarget, TargetItem = jokeTarget, graphId = story.CurrentEpisode.graphId}
                end

                table.insert(ped1Location.PossibleActions, multiActionPed1)
                table.insert(ped2Location.PossibleActions, multiActionPed2)
                
                local nextLocationPed1 = PickRandom(story.CurrentEpisode.POI)
                while nextLocationPed1.isBusy do
                    nextLocationPed1 = PickRandom(story.CurrentEpisode.POI)
                end

                local nextLocationPed2 = PickRandom(story.CurrentEpisode.POI)
                while nextLocationPed2.isBusy and nextLocationPed2 == nextLocationPed1 do
                    nextLocationPed2 = PickRandom(story.CurrentEpisode.POI)
                end

                local movePed1 = Move { performer = FIRST_ACTOR, nextLocation = nextLocationPed1, targetItem = nextLocationPed1, graphId = story.CurrentEpisode.graphId }
                local movePed2 = Move { performer = SECOND_ACTOR, nextLocation = nextLocationPed2, targetItem = nextLocationPed2, graphId = story.CurrentEpisode.graphId }

                multiActionPed1.NextAction = movePed1
                multiActionPed1.ClosingAction = movePed1
                
                multiActionPed2.NextAction = movePed2
                multiActionPed2.ClosingAction = movePed2

                multiActionPed1:Apply()
                multiActionPed2:Apply()

                MULTI_ACTION_DONE = true
            else
                if lastAction.NextAction then
                    if isArray(lastAction.NextAction) then
                        nextAction = PickRandom(lastAction.NextAction)
                    else
                        nextAction = lastAction.NextAction
                    end
                elseif lastAction.NextLocation then
                    nextAction = lastAction.NextLocation:GetNextValidAction(lastAction.Performer)
                end
    
                nextAction.Performer = lastAction.Performer
                nextAction:Apply()
            end
        else
            if lastAction.NextAction then
                if isArray(lastAction.NextAction) then
                    nextAction = PickRandom(lastAction.NextAction)
                else
                    nextAction = lastAction.NextAction
                end
            elseif lastAction.NextLocation then
                nextAction = lastAction.NextLocation:GetNextValidAction(lastAction.Performer)
            end

            nextAction.Performer = lastAction.Performer
            nextAction:Apply()
        end

    end, delay, 1, playerId, storyId)    
end