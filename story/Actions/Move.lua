Move = class(StoryActionBase, function(o, params)
    -- check mandatory options
    if not params.performer then
        error("Move: performer not given in the constructor")
    elseif not params.targetItem then
        error("Move: targetItem not given in the constructor")
    elseif not params.nextLocation then
        error("Move: nextLocation not given in the constructor")
    elseif type(params.graphId) ~= "number" then
        error("Move: graphId not given in the constructor")
    end
    local description = " goes to the "
    o.lib = Move.eLib.Ped


    if params.performer.model == 92 or params.performer.model == 99 then
        params.how = Move.eHow.Skate
        o.lib = Move.eLib.Skate
    end

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
        if DEBUG then
            print('WARNING! Move.destinationReached had the source null. Discarding the callback...')
        end
        return
    end
    local playerId = source:getData("id")
    if player:getData('id') ~= playerId then
        return
    end
    local storyId = source:getData("storyId")
    local story = CURRENT_STORY
    local lastAction = story.History[playerId][#story.History[playerId]]

	if lastAction.path and DEBUG then
		outputConsole("Player "..player:getData('name').." reached marker "..source:getData("idx").." / "..#lastAction.path)
	end
	if (lastAction.path and source:getData("idx") + 1 <= #lastAction.path) then
		local idx = source:getData("idx") + 1
		if DEBUG then
			outputConsole("Moving to "..idx)
		end
		local marker = Marker(lastAction.path[idx][1], lastAction.path[idx][2], lastAction.path[idx][3], "cylinder", 1.5, 0, 0, 0, 0)
		marker:setData("idx", idx)
		marker:setData("id", playerId)
		marker:setData("storyId", storyId)
		marker.interior = player.interior
		addEventHandler("onMarkerHit", marker, Move.destinationReached)
		player:setRotation(0,0,findRotation(player.position.x, player.position.y, lastAction.path[idx][1], lastAction.path[idx][2]))
	else
		if DEBUG then
			outputConsole("Destination reached")
		end

        player:setAnimation() --stop the animation - the player will stop moving 
        player.position = lastAction.NextLocation.position
        player.rotation = lastAction.NextLocation.rotation
        lastAction.path = nil
        if DEBUG then
            outputConsole("Move:Apply - getting next valid action")
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
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if self.TargetItem.Region and self.TargetItem.Region.Id ~= self.Performer:getData('currentRegionId') then
        if DEBUG then
            -- outputConsole("Move:Apply: Logging data because the next region is "..self.TargetItem.Region.name..' but the current region is '..story.CurrentEpisode.CurrentRegion.name)
            -- outputConsole("Move:Apply: ("..self.TargetItem.Region.Id..' vs '..self.Performer:getData('currentRegionId')..' - '..story.CurrentEpisode.CurrentRegion.Id)
        end
        story.Logger:Log(self.Description .. " " .. self.TargetItem.Description, self)
    end

    if DEBUG then
        outputConsole("Move:Apply")
    end

    StoryActionBase.Apply(self) --TODO: make this call for each action

    if self.TargetItem.Region and self.TargetItem.Region.Episode.name ~= self.Performer:getData('currentEpisode') then
        --teleport the player
        self.Performer.position = self.TargetItem.position
        self.Performer.interior = self.TargetItem.Region.Episode.InteriorId
        self.TargetItem.Region:SetRandomStaticCamera(player)
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
                self.path = result
                table.insert(self.path, {self.TargetItem.position.x, self.TargetItem.position.y, self.TargetItem.position.z})
                local nextPos = self.path[1]
                local marker = Marker(nextPos[1], nextPos[2], nextPos[3], "cylinder", 1.5, 0, 0, 0, 0)
                marker.interior = self.Performer.interior
                marker:setData("idx", 1)
                marker:setData('id', self.Performer:getData('id'))
                marker:setData('storyId', self.Performer:getData('storyId'))
                addEventHandler("onMarkerHit", marker, self.destinationReached)
            
                self.Performer:setRotation(0,0,findRotation(self.Performer.position.x, self.Performer.position.y, nextPos[1], nextPos[2]))

                Timer(function()
                    self.Performer:setAnimation(self.lib, self.how, -1, true, true, true, true)
                end, 100, 1)
            end
        end
    )
end

function Move:GetDynamicString()
    return 'return Move{graphId = '..self.graphId..', how = '..self.how..'}'
end