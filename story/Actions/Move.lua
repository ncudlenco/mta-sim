Move = class(StoryActionBase, function(o, params)
    -- check mandatory options
    if not params.targetItem then
        error("Move: targetItem not given in the constructor")
    elseif not params.nextLocation then
        error("Move: nextLocation not given in the constructor")
    elseif type(params.graphId) ~= "number" then
        error("Move: graphId not given in the constructor")
    end
    local description = " goes to the "
    o.lib = Move.eLib.Ped

    if params.how == Move.eHow.Walk then
        description = PickRandom({" goes to the ", " moves towards the ", " starts moving towards the "})
    elseif params.how == Move.eHow.Run then
        description = " runs "
    elseif params.how == Move.eHow.Skate then
        description = " skates "
    end

    params.description = description
    params.name = 'Move'

    StoryActionBase.init(o,params)
    o.planningData = {}
    o.graphId = params.graphId
    o.how = params.how or Move.eHow.Walk
    o.isMove = true
end)

Move.eLib = {
    Ped = "ped",
    Skate = "SKATE"
}

Move.eHow = {
    Walk = "WALK_civi",
    Run = "run_civi",
    Skate = "skate_run"
}

function Move.destinationReached(player, matchingDimension)
    if not source then
        if DEBUG_PATHFINDING then
            print('WARNING! Move.destinationReached had the source null. Discarding the callback...')
        end
        return
    end
    local playerId = source:getData("id")
    if player:getData('id') ~= playerId then
        if DEBUG_PATHFINDING then
            print('WARNING! Move.destinationReached - playerId was different than actual id...'..playerId..' vs '..player:getData('id'))
        end
        return
    end


    local storyId = source:getData("storyId")
    local story = CURRENT_STORY

    local lastAction = story.History[playerId][#story.History[playerId]]
    local path = lastAction.planningData[player:getData('id')].path
    if path and DEBUG_PATHFINDING then
		outputConsole("Player "..player:getData('name').." reached marker "..source:getData("idx").." / "..#path)
		print("Player "..player:getData('name').." reached marker "..source:getData("idx").." / "..#path)
	end
	if (path and source:getData("idx") + 1 <= #path) then
		local idx = source:getData("idx") + 1
		if DEBUG_PATHFINDING then
			outputConsole("Moving to "..idx)
			print("Moving to "..idx)
		end
		local marker = Marker(path[idx][1], path[idx][2], path[idx][3], "cylinder", 1.5, 255, 0, 0, 0)
		marker:setData("idx", idx)
		marker:setData("id", playerId)
		marker:setData("storyId", storyId)
		marker.interior = player.interior
		addEventHandler("onMarkerHit", marker, Move.destinationReached)
		player:setRotation(0,0,findRotation(player.position.x, player.position.y, path[idx][1], path[idx][2]))
	else
		if DEBUG_PATHFINDING then
			outputConsole("Destination reached")
			print("Destination reached")
		end

        if #lastAction.planningData[player:getData('id')].contextSegments > 0 then
            --teleport player to next context, save snapshot for that player
            local nextPoi = lastAction.planningData[player:getData('id')].contextSegments[1]
            print('!!!!!!!!!!!!!Teleporting player '..player:getData('id')..' to context '..nextPoi.Episode.name)
            player:setAnimation() --stop the animation - the player will stop moving
            player.position = nextPoi.position
            player.rotation = nextPoi.rotation
            player.interior = nextPoi.Episode.InteriorId
            table.remove(lastAction.planningData[player:getData('id')].contextSegments, 1)

            --Will be continued when the target episode gets in focus
            player:setData('paused', true)
            lastAction.planningData[player:getData('id')].paused = true
            print('Paused player '..player:getData('id'))
            --make sure the region player hit event was triggered
            nextPoi.Region:OnPlayerHit(player)
            story.CameraHandler:requestFocus(player:getData('id')) --Actors changing contexts get an extra focus request
        else
            player:setAnimation() --stop the animation - the player will stop moving
            player.position = lastAction.NextLocation.position
            player.rotation = lastAction.NextLocation.rotation
            lastAction.planningData[player:getData('id')] = {}
            if DEBUG_PATHFINDING then
                outputConsole("Move:Apply - getting next valid action")
                print("Move:Apply - getting next valid action")
            end
            OnGlobalActionFinished(0, player:getData('id'), player:getData('storyId'))
        end
	end
	removeEventHandler("onMarkerHit", source, destinationReached)
	source:destroy()

    -- if player:getData('hasFocus') then
    --     Timer(function()
    --         story.CameraHandler:updatePerspective(playerId)
    --     end, 100, 1)
    -- else
        story.CameraHandler:requestFocus(playerId)
    -- end
end

--returns the shortest path between linked episodes, maybe memoize this?
function Move:getLinks(currentEpisodeName, processedEpisodes)
    local story = GetStory(self.Performer)
    if #processedEpisodes > 0 and currentEpisodeName == self.NextLocation.Episode.name then
        local targetEntrylink = FirstOrDefault(story.CurrentEpisode.episodeLinks, function(link) return link.sourcePoi.Episode.name == self.NextLocation.Episode.name and link.targetEpisode.name == processedEpisodes[1] end)
        if not targetEntrylink then
            print('Warning! Could not find a backwards link between '..currentEpisodeName..' and '..processedEpisodes[1])
        else
            return {targetEntrylink.sourcePoi}
        end
    end

    local exitsFromCurrentContext = Where(story.CurrentEpisode.episodeLinks, function(link) return link.sourcePoi.Episode.name == currentEpisodeName and not inList(link.targetEpisode.name, processedEpisodes) end)
    local nextLinks = DropNull(Select(exitsFromCurrentContext, function(link)
        local links = self:getLinks(link.targetEpisode.name, concat({currentEpisodeName}, processedEpisodes))
        if links then
            return concat({link.sourcePoi}, links)
        else
            return nil
        end
    end))
    return reduceLeft(nextLinks, nil, function(a, b) if #a < #b then return a else return b end end)
end

function Move:Apply()
    if not self.Performer then
        error("Performer was not set in action Move")
    end
    local lib = self.lib
    local how = self.how
    if self.Performer.model == 92 or self.Performer.model == 99 then
        how = Move.eHow.Skate
        lib = Move.eLib.Skate
    end

    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if self.TargetItem.Region and self.TargetItem.Region.Id ~= self.Performer:getData('currentRegionId') then
        if DEBUG then
            -- outputConsole("Move:Apply: Logging data because the next region is "..self.TargetItem.Region.name..' but the current region is '..story.CurrentEpisode.CurrentRegion.name)
            -- outputConsole("Move:Apply: ("..self.TargetItem.Region.Id..' vs '..self.Performer:getData('currentRegionId')..' - '..story.CurrentEpisode.CurrentRegion.Id)
        end
        StoryActionBase.GetLogger(self, story):Log(self.Description .. " " .. self.TargetItem.Description, self)
    end

    if DEBUG then
        outputConsole("Move:Apply")
        print("Move:Apply")
    end

    local contextSegments = {self.NextLocation}
    StoryActionBase.Apply(self) --TODO: make this call for each action!!!!!!!!!!
    if self.NextLocation.Episode and self.NextLocation.Episode.name ~= self.Performer:getData('currentEpisode') then
        print('SWITCHING CONTEXT')

        local contextSwitchingPath = self:getLinks(self.Performer:getData('currentEpisode'), {})
        if not contextSwitchingPath then
            print('Warning! Actor '..self.Performer:getData('id')..' wanted to go to a different context '..self.NextLocation.Episode.name..' but we could not find a path')
        end
        contextSegments = concat(contextSwitchingPath, contextSegments)
    end

    self.planningData[self.Performer:getData('id')] = {
        path = {},
        contextSegments = contextSegments,
        how = how,
        lib = lib,
        paused = self.Performer:getData('paused'),
        timeout = math.max(1, #contextSegments) * 45
    }
    if not self.Performer:getData('paused') then
        self:FindNextShortestPath(self.Performer)
    end
end

function Move:FindNextShortestPath(player)
    local contextSegments = self.planningData[player:getData('id')].contextSegments
    if #contextSegments == 0 then
        error("Move:FindNextShortestPath - The number of context segments was 0!")
    end
    print("Find shortest path between "..player:getData('currentRegion')..' and '..contextSegments[1].Region.name)
    findShortestPathBetween(
        contextSegments[1].Episode.graphId,
        player.position.x, player.position.y, player.position.z,
        contextSegments[1].position.x, contextSegments[1].position.y, contextSegments[1].position.z,
        function(result)
            if (result) then
                local lib = self.planningData[player:getData('id')].lib
                local how = self.planningData[player:getData('id')].how

                if DEBUG_PATHFINDING then
                    print('Path found between '..player:getData('id')..' and '..self.TargetItem.Region.name)
                    local colorCode = 255
                    for _,p in ipairs(result) do
                        Marker(p[1], p[2], p[3], "cylinder", 1.5, colorCode, colorCode, colorCode, 128)
                    end
                end
                self.planningData[player:getData('id')].path = result
                local targetPosition = self.planningData[player:getData('id')].contextSegments[1].position
                table.insert(self.planningData[player:getData('id')].path, {targetPosition.x, targetPosition.y, targetPosition.z})
                table.remove(self.planningData[player:getData('id')].contextSegments, 1)
                local nextPos = self.planningData[player:getData('id')].path[1]
                local marker = Marker(nextPos[1], nextPos[2], nextPos[3], "cylinder", 1.5, 255, 0, 0, 0)
                marker.interior = player.interior
                marker:setData("idx", 1)
                marker:setData('id', player:getData('id'))
                marker:setData('storyId', player:getData('storyId'))
                addEventHandler("onMarkerHit", marker, self.destinationReached)

                player:setRotation(0,0,findRotation(player.position.x, player.position.y, nextPos[1], nextPos[2]))

                Timer(function()
                    player:setAnimation(lib, how, -1, true, true, true, true)
                end, 100, 1)
                local function wait(player)
                    if CURRENT_STORY.Disposed then
                        return
                    end
                    if player == nil or player:getData('id') == nil then
                        outputConsole("Move:wait - #@!#!# THE PLAYER OR PLAYER ID IS NULL ")
                    end
                    local playerId = player:getData('id')
                    local story = CURRENT_STORY
                    local lastAction = story.History[playerId][#story.History[playerId]]
                    local path = lastAction.planningData[playerId].path
                    if
                        not lastAction
                        or not lastAction.planningData
                        or not lastAction.planningData[playerId]
                        or not lastAction.planningData[playerId].timeout
                        or #path == 0
                        or lastAction.planningData[playerId] == {}
                    then
                        outputConsole("Move:wait - Timeout is null for player "..playerId)
                        --Action finished => kill the Timer
                        return
                    end

                    if lastAction.planningData[playerId].paused then
                        Timer(wait, 1000, 1, player)
                        return
                    end

                    lastAction.planningData[playerId].timeout = lastAction.planningData[playerId].timeout - 1
                    outputConsole("Move:wait - Timeout is "..lastAction.planningData[playerId].timeout.." for player "..player:getData('id'))
                    if lastAction.planningData[playerId].timeout > 0 then
                        Timer(wait, 1000, 1, player)
                    else
                        --Teleport player
                        player:setAnimation() --stop the animation - the player will stop moving
                        player.position = lastAction.NextLocation.position
                        player.rotation = lastAction.NextLocation.rotation
                        lastAction.planningData[playerId] = {}
                        if DEBUG_PATHFINDING then
                            outputConsole("Move:wait - Timeout expired for actor "..playerId)
                            print("Move:wait - Timeout expired for actor "..playerId)
                        end
                        OnGlobalActionFinished(0, playerId, player:getData('storyId'))
                    end
                end
                wait(player)
            else
                error('No shortest path found!')
            end
        end
    )
end

function Move:GetDynamicString()
    return 'return Move{graphId = '..self.graphId..', how = '..self.how..'}'
end
function Move:isFinished(player)
    if self.planningData[player:getData('id')] and self.planningData[player:getData('id')].how then return false else return true end
end

function Move:pause(player)
    player:setAnimation() --Stop the player wherever it is
    print('Pause called for '..player:getData('id'))
    local plan = self.planningData[self.Performer:getData('id')]
    if plan then
        if plan.paused then
            self.planningData[self.Performer:getData('id')].paused = true
        end
    end
end

function Move:resume(player)
    print('Resume called for '..player:getData('id'))
    local plan = self.planningData[self.Performer:getData('id')]
    if plan then
        if plan.paused then
            self.planningData[self.Performer:getData('id')].paused = false
            self:FindNextShortestPath(self.Performer)
        else
            player:setAnimation(plan.lib, plan.how, -1, true, true, true, true)
        end
    else
        error('No plan to resume for '..player:getData('id'))
    end
end