Move = class(StoryActionBase, function(o, params)
    -- check mandatory options
    -- if not params.targetItem then
    --     error("Move: targetItem not given in the constructor")
    -- elseif not params.nextLocation then
    --     error("Move: nextLocation not given in the constructor")
    -- elseif type(params.graphId) ~= "number" then
    --     error("Move: graphId not given in the constructor")
    -- end
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

GLOBAL_LOCKS = {}
function Move.acquireLock(playerId, markerId)
    if GLOBAL_LOCKS[playerId] and GLOBAL_LOCKS[playerId][markerId] then
        return false
    else
        GLOBAL_LOCKS[playerId] = {}
        GLOBAL_LOCKS[playerId][markerId] = true
        return true
    end
end
function Move.releaseLock(playerId)
    GLOBAL_LOCKS[playerId] = {}
    return true
end
function Move.destinationReached(player, source)
    if not source then
        if DEBUG_PATHFINDING then
            print('WARNING! Move.destinationReached had the source null. Discarding the callback...')
        end
        return
    end
    local playerId = source:getData("id")
    local sourceIdx = source:getData("idx")
    if player:getData('id') ~= playerId then
        if DEBUG_PATHFINDING then
            print('WARNING! Move.destinationReached - playerId was different than actual id...'..playerId..' vs '..player:getData('id'))
        end

        player = nil
        for _, ped in ipairs(CURRENT_STORY.CurrentEpisode.peds) do
            if ped:getData('id') == playerId and math.abs((ped.position - source.position).length) < 1.5 then
                player = ped
                break
            end
        end
        if player == nil then
            return --The needed player is not in range for this marker. Skipping, reprocessing neede.
        end
    end
    if source:getData('processed') then
        print('WARNING! Move.destinationReached was already processed for '..playerId..' and marker '..sourceIdx)
        return -- And the source is already proably destroyed.
    end

    local sourcePosition = source.position
    local storyId = source:getData("storyId")

    local story = CURRENT_STORY
    local lastAction = story.History[playerId][#story.History[playerId]]
    local path = lastAction.planningData[playerId].path
    if lastAction.planningData[playerId].paused then
        print("Outer check: Skipped marker "..sourceIdx..' for actor '..playerId..' because the plan is paused')
        return --The marker needs to be reprocessed when the action is resumed.
    end
    player:setAnimation()
    if path and DEBUG_PATHFINDING then
		outputConsole("Player "..player:getData('name').." reached marker "..sourceIdx.." / "..#path)
		print("Player "..player:getData('name').." reached marker "..sourceIdx.." / "..#path)
	end
	if (path and sourceIdx + 1 <= #path) then
		local idx = sourceIdx + 1
		if DEBUG_PATHFINDING then
			outputConsole("Moving to "..idx)
			print("Moving to "..idx)
		end
		local marker = Marker(path[idx][1], path[idx][2], path[idx][3], "cylinder", 1.5, 255, 0, 0, 0)
		marker:setData("idx", idx)
        player:setData('idx', idx)
		marker:setData("id", playerId)
		marker:setData("storyId", storyId)

        marker.interior = player.interior
        lastAction.planningData[playerId].nextMarker = marker

        Move.hasReachedMarker(player, marker)

        lastAction.planningData[playerId].timeout = 60
        -- player.position = Vector3(sourcePosition.x, sourcePosition.y, player.position.z)

        if lastAction.planningData[playerId].paused then
            print("Skipped marker "..idx..' for actor '..playerId..' because the plan is paused')
            return --Because it needs to be re-processed
        elseif math.abs((player.position - Vector3(path[idx][1], path[idx][2], player.position.z)).length) < 0.0001 then
            print("Skipped marker "..idx..' for actor '..playerId..' because the player is already located at these coordinates')
        else
            -- print("ROTATION: "..player.rotation.z..'; Position: '..player.position.x..', '..player.position.y..', '..player.position.z..'; Target: '..path[idx][1]..', '..path[idx][2])
            player:setRotation(0,0,findRotation(player.position.x, player.position.y, path[idx][1], path[idx][2]), "default", true)
            -- print("After computation ROTATION: "..player.rotation.z..'; Position: '..player.position.x..', '..player.position.y..', '..player.position.z)

            local lib = lastAction.planningData[player:getData('id')].lib
            local how = lastAction.planningData[player:getData('id')].how
            player:setAnimation(lib, how, -1, true, true, true, true)
        end
        if not DISABLE_BETWEEN_POINTS_TELEPORTATION then
            Move.wait(player)
        end
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
            for _, context in ipairs(lastAction.planningData[player:getData('id')].contextSegments) do
                print("Contexts: ["..player:getData('id').."]. Target location: "..context.Description.." in region: "..context.Region.name.." and episode: "..context.Episode.name)
            end
            lastAction.planningData[playerId].path = {}
            lastAction.planningData[playerId].nextMarker = nil
            lastAction.planningData[player:getData('id')].resumePoi = nextPoi

            --Will be continued when the target episode gets in focus
            lastAction:pause(player)
            --make sure the region player hit event was triggered - needed to set the player's region and episode
            nextPoi.Region:OnPlayerHit(player)
            story.CameraHandler:requestFocus(player:getData('id')) --Actors changing contexts get an extra focus request
        else
            player:setAnimation() --stop the animation - the player will stop moving
            player.position = lastAction.NextLocation.position
            player.rotation = lastAction.NextLocation.rotation
            -- player.interior = lastAction.NextLocation.Episode.InteriorId
            lastAction.planningData[player:getData('id')] = {}
            if DEBUG_PATHFINDING then
                outputConsole("Move:Apply - getting next valid action")
                print("Move:Apply - getting next valid action")
            end
            OnGlobalActionFinished(0, player:getData('id'), player:getData('storyId'))
        end
	end

    -- if player:getData('hasFocus') then
    --     Timer(function()
    --         story.CameraHandler:updatePerspective(playerId)
    --     end, 100, 1)
    -- else
        story.CameraHandler:requestFocus(playerId)
    -- end
    source:setData('processed', true)
    source:destroy()
    source = nil
end

function Move:findLink(sourceEpisode, targetEpisode)
    local story = GetStory(self.Performer)
    return FirstOrDefault(story.CurrentEpisode.episodeLinks, function(link)
        if DEBUG_CHAIN_LINKED_ACTIONS then
            print(link.sourcePoi.Episode.name or 'null source poi episode name')
            print(self.NextLocation.Episode.name or 'null target poi episode name')
            print(link.targetEpisode.name or 'null target episode name')
            print(processedEpisodes[1] or 'null processed episodes')
        end
        return link.sourcePoi.Episode.name == sourceEpisode and link.targetEpisode.name == targetEpisode
    end)
end

--returns the shortest path between linked episodes, maybe memoize this?
function Move:getLinks(currentEpisodeName, processedEpisodes)
    local story = GetStory(self.Performer)
    if #processedEpisodes > 0 and currentEpisodeName == self.NextLocation.Episode.name then
        local backwardsLink = self:findLink(currentEpisodeName, processedEpisodes[1])
        if not backwardsLink then
            print('Warning! Could not find a backwards link between '..currentEpisodeName..' and '..processedEpisodes[1])
            return nil
        else
            return {backwardsLink.sourcePoi, self.NextLocation}
        end
    end

    local exitsFromCurrentContext = Where(story.CurrentEpisode.episodeLinks, function(link) return link.sourcePoi.Episode.name == currentEpisodeName and not inList(link.targetEpisode.name, processedEpisodes) end)
    local nextLinks = DropNull(Select(exitsFromCurrentContext, function(link)
        local links = self:getLinks(link.targetEpisode.name, concat({currentEpisodeName}, processedEpisodes))
        if links then
            if #processedEpisodes > 0 then
                local backwardsLink = self:findLink(currentEpisodeName, processedEpisodes[1])
                if not backwardsLink then
                    print('Warning! Could not find a backwards link between '..currentEpisodeName..' and '..processedEpisodes[1])
                    return nil
                else
                    return concat({backwardsLink.sourcePoi, link.sourcePoi}, links)
                end
            else
                return concat({link.sourcePoi}, links)
            end
        else
            return nil
        end
    end))
    return reduceLeft(nextLinks, nil, function(a, b) if #a < #b then return a else return b end end)
end

function Move:Apply()
    if not self.Performer then
        print("[Move][FATAL ERROR]Performer was not set in action Move!")
        return
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
    local teleport = false
    if self.NextLocation.Episode and self.NextLocation.Episode.name ~= self.Performer:getData('currentEpisode') then
        print('SWITCHING CONTEXT')

        local contextSwitchingPath = self:getLinks(self.Performer:getData('currentEpisode'), {})
        if not contextSwitchingPath then
            print('Warning! Actor '..self.Performer:getData('id')..' wanted to go to a different context '..self.NextLocation.Episode.name..' from '..(self.Performer:getData('currentEpisode') or 'null')..'but we could not find a path')
            teleport = true
        else
            contextSegments = contextSwitchingPath
        end
    end

    self.planningData[self.Performer:getData('id')] = {
        path = {},
        contextSegments = contextSegments,
        how = how,
        lib = lib,
        paused = self.Performer:getData('paused'),
        timeout = math.max(1, #contextSegments) * 45,
        nextMarker = nil
    }
    if teleport then
        Timer(Move.teleport, 5000, 1, self.Performer, self)
    end
    if not teleport and not self.Performer:getData('paused') then
        self:FindNextShortestPath(self.Performer)
    end
end

--Find the closest graph node in the current region and sets it as the first page in the path.
--Afterwards uses the library to find the shortest distance between the node and the target (might still have problems, if the target is near a wal, in another room next to a node)
function Move:InternalShortestPath(graphId, pathfindingGraph, source, sourceRegion, target, targetRegion, callback)
    local start = nil
    if pathfindingGraph and sourceRegion then
        local min = 99999
        local nodesInRegion = Where(pathfindingGraph, function(node) return node.Region and node.Region:__eq(sourceRegion) end)
        for _, p in ipairs(nodesInRegion) do
            local distance = math.abs((Vector3(p.x, p.y, p.z) - source).length)
            if distance < min then
                min = distance
                start = p
            end
        end
        print("INFO, pathfinding graph and source region '"..sourceRegion.name.."'found for start point")
    else
        print("WARNING, no pathfinding graph or source region for start point")
    end
    local last = nil
    if pathfindingGraph and targetRegion then
        local min = 99999
        local nodesInTargetRegion = Where(pathfindingGraph, function(node) return node.Region and node.Region:__eq(targetRegion) end)
        for _, p in ipairs(nodesInTargetRegion) do
            local distance = math.abs((Vector3(p.x, p.y, p.z) - target).length)
            if distance < min then
                min = distance
                last = p
            end
        end
        print("INFO, pathfinding graph and source region found for end point")
    else
        print("WARNING, no pathfinding graph or source region for end point")
    end

    local from = source
    local custom_callback = callback
    if start and true or false then
        from = start
        custom_callback = function(result)
            if DEBUG then
                local length = 0
                if result then
                    length = #result
                end
                print("Custom callback found path of length "..length)
            end
            if result then
                callback(concat({{start.x, start.y, start.z}}, result))
            else
                callback(nil)
            end
        end
    end
    local to = target
    if last and true or false then
        to = last
    end
    findShortestPathBetween(
        graphId,
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        custom_callback
    )
end

function Move:InitializeMarker(x, y, z, player)
    local marker = Marker(x, y, z, "cylinder", 1.5, 255, 0, 0, 0)
    marker.interior = player.interior
    marker:setData("idx", 1)
    player:setData("idx", 1)
    marker:setData('id', player:getData('id'))
    marker:setData('storyId', player:getData('storyId'))
    self.planningData[player:getData('id')].nextMarker = marker
    return marker
end

DEBUG_MARKERS = {}
function Move:FindNextShortestPath(player)
    for _, context in ipairs(self.planningData[player:getData('id')].contextSegments) do
        print("Contexts: ["..player:getData('id').."]. Target location: "..context.Description.." in region: "..context.Region.name.." and episode: "..context.Episode.name)
    end
    local contextSegments = self.planningData[player:getData('id')].contextSegments
    if #contextSegments == 0 then
        print("[FATAL ERROR!] Move:FindNextShortestPath - The number of context segments was 0!")
        Timer(Move.teleport, 5000, 1, self.Performer, self)
        return
    elseif contextSegments[1].Episode == nil then
        print("[FATAL ERROR!] Move:FindNextShortestPath - The episode of the next context segment was null!")
        Timer(Move.teleport, 5000, 1, self.Performer, self)
        return
    elseif contextSegments[1].Episode == nil then
        print("[FATAL ERROR!] Move:FindNextShortestPath - The episode of the next context segment was null!")
        Timer(Move.teleport, 5000, 1, self.Performer, self)
        return
    end
    local resumePoi = self.planningData[player:getData('id')].resumePoi
    if resumePoi then
        player.position = resumePoi.position
        player.rotation = resumePoi.rotation
        player.interior = resumePoi.Episode.InteriorId
        resumePoi.Region:OnPlayerHit(player)
    end
    if contextSegments[1].Episode.name ~= player:getData('currentEpisode') then
        print("[FATAL ERROR!] Move:FindNextShortestPath - The context segment episode ".. contextSegments[1].Episode.name .." was different than the player episode "..player:getData('currentEpisode').."!")
        Timer(Move.teleport, 5000, 1, self.Performer, self)
        return
    end
    print("Find shortest path between "..(player:getData('currentRegion') or 'null')..' and '..(contextSegments[1].Region.name or 'null'))
    if math.abs((player.position - contextSegments[1].position).length) < 1.5 then
        local m = self:InitializeMarker(contextSegments[1].position.x, contextSegments[1].position.y, contextSegments[1].position.z, player)
        self.planningData[player:getData('id')].paused = false
        table.remove(self.planningData[player:getData('id')].contextSegments, 1)
        Move.destinationReached(player, m)
    else
        self:InternalShortestPath(
            contextSegments[1].Episode.graphId,
            contextSegments[1].Episode.pathfindingGraph, --pathfindingGraph
            player.position,
            FirstOrDefault(contextSegments[1].Episode.Regions, function(r) return r.name == player:getData('currentRegion') end), -- source region
            contextSegments[1].position,
            contextSegments[1].Region,
            function(result)
                if (result) then
                    local lib = self.planningData[player:getData('id')].lib
                    local how = self.planningData[player:getData('id')].how

                    if DEBUG_PATHFINDING then
                        local strActorIdx = string.gsub(player:getData('id'), "actor", "")
                        print('Path found between '..player:getData('id')..' and '..self.TargetItem.Region.name..' actor idx:'..strActorIdx)
                        local actorIdx = tonumber(strActorIdx) + 1
                        print('As nr '..actorIdx)
                        local colorCode = 255 / 4 * actorIdx
                        if DEBUG_MARKERS[player:getData('id')] then
                            for _,m in ipairs(DEBUG_MARKERS[player:getData('id')]) do
                                m:destroy()
                                m = nil
                            end
                        end
                        DEBUG_MARKERS[player:getData('id')] = {}
                        for _,p in ipairs(result) do
                            local m = Marker(p[1], p[2], p[3], "cylinder", 1.5, colorCode, colorCode, colorCode, 255)
                            m.interior = player.interior
                            table.insert(DEBUG_MARKERS[player:getData('id')], m)
                        end
                    end
                    self.planningData[player:getData('id')].path = result
                    local targetPosition = self.planningData[player:getData('id')].contextSegments[1].position
                    table.insert(self.planningData[player:getData('id')].path, {targetPosition.x, targetPosition.y, targetPosition.z})
                    table.remove(self.planningData[player:getData('id')].contextSegments, 1) ------ The context should only be removed when the player reaches the end of the current segment (done in destinationReached)
                    local nextPos = self.planningData[player:getData('id')].path[1]
                    while math.abs((player.position - Vector3(nextPos[1], nextPos[2], nextPos[3])).length) < 1.5 do
                        table.remove(self.planningData[player:getData('id')].path, 1)
                        nextPos = self.planningData[player:getData('id')].path[1]
                    end

                    self.planningData[player:getData('id')].timeout = 60
                    print("THE TIMEOUT IS "..self.planningData[player:getData('id')].timeout)
                    -- V = d / t ; t = d / V, assume V = 1
                    local marker = self:InitializeMarker(nextPos[1], nextPos[2], nextPos[3], player)
                    self.planningData[player:getData('id')].paused = false
                    Move.hasReachedMarker(player, marker)

                    player:setRotation(0,0,findRotation(player.position.x, player.position.y, nextPos[1], nextPos[2]), "default", true)

                    Timer(function()
                        player:setAnimation(lib, how, -1, true, true, true, true)
                    end, 100, 1)
                    if not DISABLE_BETWEEN_POINTS_TELEPORTATION then
                        Move.wait(player)
                    end
                else
                    print('[FATAL ERROR!] No shortest path found!')
                end
            end
        )
    end
end

function Move.hasReachedMarker(player, marker)
    if not marker or not isElement(marker) or not marker.position then
        print("[Warning] The marker was null while calling Move.hasReachedMarker")
        return
    end
    if not player or not player.position then
        print("[FATAL ERROR] The player was null while calling Move.hasReachedMarker")
        return
    end
    local playerId = player:getData('id')
    local story = CURRENT_STORY
    local lastAction = story.History[playerId][#story.History[playerId]]
    local plan = lastAction.planningData[playerId]
    local distance = math.abs((player.position - marker.position).length)
    -- print('Actor '..playerId..' distance to marker '..marker:getData('idx')..' is '..distance..' and marker size is '..marker.size)
    if distance < marker.size then
        print('Actor '..playerId..' has reached marker '..marker:getData('idx'))
        Move.destinationReached(player, marker)
    elseif not CURRENT_STORY.Disposed then
        if plan and #plan.path > 0 then
            local idx = player:getData('idx')
            -- print("ROTATION: "..player.rotation.z..'; Position: '..player.position.x..', '..player.position.y..', '..player.position.z..'; Target: '..plan.path[idx][1]..', '..plan.path[idx][2])
            player:setRotation(0,0,findRotation(player.position.x, player.position.y, plan.path[idx][1], plan.path[idx][2]), "default", true)
            -- print("After computation ROTATION: "..player.rotation.z..'; Position: '..player.position.x..', '..player.position.y..', '..player.position.z)
            player:setAnimation(plan.lib, plan.how, -1, true, true, true, true)
            print('Actor '..playerId..' rerunning timer for marker '..marker:getData('idx'))
            Timer(Move.hasReachedMarker, 1000, 1, player, marker)
        else
            print("[FATAL ERROR] "..playerId..". The player had no plan or the path is empty but Move.hasReachedMarker has been called")
        end
    end
end

function Move.wait(player)
    if CURRENT_STORY.Disposed or DISABLE_BETWEEN_POINTS_TELEPORTATION then
        return
    end
    if player == nil or player:getData('id') == nil then
        outputConsole("Move:wait - #@!#!# THE PLAYER OR PLAYER ID IS NULL ")
    end
    local playerId = player:getData('id')
    local story = CURRENT_STORY
    local lastAction = story.History[playerId][#story.History[playerId]]
    if
        not lastAction
        or not lastAction.planningData
        or not lastAction.planningData[playerId]
        or not lastAction.planningData[playerId].timeout
        or not lastAction.planningData[playerId].path
        or #lastAction.planningData[playerId].path == 0
        or lastAction.planningData[playerId] == {}
    then
        outputConsole("Move:wait - Timeout is null for player "..playerId)
        --Action finished => kill the Timer
        return
    end

    if lastAction.planningData[playerId].paused then
        Timer(Move.wait, 1000, 1, player)
        return
    end

    lastAction.planningData[playerId].timeout = lastAction.planningData[playerId].timeout - 1
    outputConsole("Move:wait - Timeout is "..lastAction.planningData[playerId].timeout.." for player "..player:getData('id'))
    if lastAction.planningData[playerId].timeout > 0 then
        -- local nextPos = lastAction.planningData[playerId].path[1]
        -- player:setRotation(0,0,findRotation(player.position.x, player.position.y, nextPos[1], nextPos[2]), "default", true)
        Timer(Move.wait, 1000, 1, player)
    else
        Move.teleport(player, lastAction)
    end
end

function Move.teleport(player, lastAction)
    local playerId = player:getData('id')
    local nextIdx = player:getData('idx')
    local nextPos = lastAction.planningData[playerId].path[nextIdx]
    --Teleport player
    if nextPos then
        player.position = Vector3(nextPos[1], nextPos[2], nextPos[3]+0.5)
        print("Move.teleport - Teleport applied for actor "..playerId..' to an intermediate location, trying to recover the Move.')
        return
    else
        player:setAnimation() --stop the animation - the player will stop moving
        player.position = lastAction.NextLocation.position
        player.interior = lastAction.NextLocation.Episode.InteriorId
        player.rotation = lastAction.NextLocation.rotation
        lastAction.planningData[playerId] = {}
    end
    if DEBUG_PATHFINDING then
        outputConsole("Move.teleport - Teleport applied for actor "..playerId..'. Calling Action finished...')
        print("Move.teleport - Teleport applied for actor "..playerId..'. Calling Action finished...')
    end
    OnGlobalActionFinished(0, playerId, player:getData('storyId'))
end

function Move:GetDynamicString()
    return 'return Move{graphId = -1, how = '..self.how..'}'
end
function Move:isFinished(player)
    if self.planningData[player:getData('id')] and self.planningData[player:getData('id')].how then return false else return true end
end

function Move:pause(player)
    player:setData('paused', true)
    player:setAnimation() --Stop the player wherever it is
    print('Pause called for '..player:getData('id'))
    if self.planningData[self.Performer:getData('id')] then
        self.planningData[self.Performer:getData('id')].paused = true
    else
        print('[FATAL ERROR] [Move:pause] Could not find a plan for '..player:getData('id'))
    end
end

function Move:resume(player)
    Timer(function()
        print('Resume called for '..player:getData('id'))
        local plan = self.planningData[player:getData('id')]
        if plan then
            if #plan.contextSegments > 0 and #plan.path == 0 then
                print('The plan had an empty path for '..player:getData('id'))
                self:FindNextShortestPath(player)
                return
            elseif plan.paused then
                print('The plan is paused for '..player:getData('id'))
                self.planningData[player:getData('id')].paused = false
            else
                print('The plan was not paused for '..player:getData('id'))
            end
            Move.hasReachedMarker(player, plan.nextMarker)
        else
            print('[MOVE:resume][FATAL ERROR]No plan to resume for '..player:getData('id'))
        end
    end, 2000, 1, player)
end