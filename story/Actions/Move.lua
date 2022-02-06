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
    o.path = {}
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

	if lastAction.path and DEBUG_PATHFINDING then
		outputConsole("Player "..player:getData('name').." reached marker "..source:getData("idx").." / "..#lastAction.path)
		print("Player "..player:getData('name').." reached marker "..source:getData("idx").." / "..#lastAction.path)
	end
	if (lastAction.path and source:getData("idx") + 1 <= #lastAction.path) then
		local idx = source:getData("idx") + 1
		if DEBUG_PATHFINDING then
			outputConsole("Moving to "..idx)
			print("Moving to "..idx)
		end
		local marker = Marker(lastAction.path[idx][1], lastAction.path[idx][2], lastAction.path[idx][3], "cylinder", 1.5, 255, 0, 0, 0)
		marker:setData("idx", idx)
		marker:setData("id", playerId)
		marker:setData("storyId", storyId)
		marker.interior = player.interior
		addEventHandler("onMarkerHit", marker, Move.destinationReached)
		player:setRotation(0,0,findRotation(player.position.x, player.position.y, lastAction.path[idx][1], lastAction.path[idx][2]))
	else
		if DEBUG_PATHFINDING then
			outputConsole("Destination reached")
			print("Destination reached")
		end

        player:setAnimation() --stop the animation - the player will stop moving 
        player.position = lastAction.NextLocation.position
        player.rotation = lastAction.NextLocation.rotation
        lastAction.path = nil
        if DEBUG_PATHFINDING then
            outputConsole("Move:Apply - getting next valid action")
            print("Move:Apply - getting next valid action")
        end
        OnGlobalActionFinished(0, player:getData('id'), player:getData('storyId'))
	end
	removeEventHandler("onMarkerHit", source, destinationReached)
	source:destroy()

    local regionId = player:getData('currentRegionId')
    local region = FirstOrDefault(story.CurrentEpisode.Regions, function(r) return r.Id == regionId end)
    if region then
        region:SetRandomStaticCamera(player)
    end
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

    StoryActionBase.Apply(self) --TODO: make this call for each action!!!!!!!!!!
    self.Performer:setData('isMovingBetweenEpisodes', false)
    if self.TargetItem.Region and self.TargetItem.Region.Episode.name ~= self.Performer:getData('currentEpisode') then
        --find where is the POI that has as link the target item episode
        -- local linkPoi = FirstOrDefault(story.CurrentEpisode.POI, function(poi) return inList(poi.episodeLinks, self.TargetItem.Region.Episode.name) end)
        -- if not linkPoi then
        --     print('Warning! Actor '..self.Performer:getData('id')..' wanted to go to a different context '..self.TargetItem.Region.Episode.name..' but a POI with such a link was not found')
        -- end
        self.Performer:setData('isMovingBetweenEpisodes', true)
        self.Performer.position = self.TargetItem.position
        self.Performer.interior = self.TargetItem.Region.Episode.InteriorId
        self.TargetItem.Region:SetRandomStaticCamera(self.Performer)
        Timer(function()
            OnGlobalActionFinished(0, self.Performer:getData('id'), self.Performer:getData('storyId'))
            self.Performer:setAnimation()
        end, 2000, 1)
        return
    end

    --TODO: set on POI a property: episode_id (ex. garden)
    --set on each actor a property: episode
    --if the current actor's episode is not the same as the targetItem episode then
    --find pois in the current episode which link to the target episode DFS through context-switching POIs in the subset of currentEpisode linked episodes
    --add a context switch action: teleports actor to the given coordinates and sets it's interior id
    --plan an array of array of in-episode move operations with context switches in between
    --change camera when any action is about to be performed. special case move action. (remove prefered location)
    self.path = {}
    findShortestPathBetween(
        self.graphId, 
        self.Performer.position.x, self.Performer.position.y, self.Performer.position.z,
        self.TargetItem.position.x, self.TargetItem.position.y, self.TargetItem.position.z,
        function(result)
            if (result) then
                if DEBUG_PATHFINDING then
                    print('Path found between '..self.Performer:getData('id')..' and '..self.TargetItem.Region.name)
                    local colorCode = 255
                    for _,p in ipairs(result) do
                        Marker(p[1], p[2], p[3], "cylinder", 1.5, colorCode, colorCode, colorCode, 128)
                    end
                end
                self.path = result
                table.insert(self.path, {self.TargetItem.position.x, self.TargetItem.position.y, self.TargetItem.position.z})
                local nextPos = self.path[1]
                local marker = Marker(nextPos[1], nextPos[2], nextPos[3], "cylinder", 1.5, 255, 0, 0, 0)
                marker.interior = self.Performer.interior
                marker:setData("idx", 1)
                marker:setData('id', self.Performer:getData('id'))
                marker:setData('storyId', self.Performer:getData('storyId'))
                addEventHandler("onMarkerHit", marker, self.destinationReached)
            
                self.Performer:setRotation(0,0,findRotation(self.Performer.position.x, self.Performer.position.y, nextPos[1], nextPos[2]))

                Timer(function()
                    self.Performer:setAnimation(lib, how, -1, true, true, true, true)
                end, 100, 1)
            end
        end
    )
end

function Move:GetDynamicString()
    return 'return Move{graphId = '..self.graphId..', how = '..self.how..'}'
end