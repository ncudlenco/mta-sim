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
    local description = " goes in the "
    o.lib = Move.eLib.Ped


    if params.performer.model == 92 or params.performer.model == 99 then
        params.how = Move.eHow.Skate
        o.lib = Move.eLib.Skate
    end

    if params.how == Move.eHow.Walk then
        description = " goes in the "
    elseif params.how == Move.eHow.Run then
        description = " runs "
    elseif params.how == Move.eHow.Skate then
        description = " skates "
    end

    StoryActionBase.init(o, description, params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.path = {}
    o.graphId = params.graphId
    o.how = params.how or Move.eHow.Walk
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
    local playerId = source:getData("id")
    local storyId = source:getData("storyId")
    local story = STORIES[playerId][storyId]
    local lastAction = story.History[#story.History]

	if lastAction.path and DEBUG then
		outputConsole("Player "..player.name.." reached marker "..source:getData("idx").." / "..#lastAction.path)
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

        player:setAnimation()
        player.position = lastAction.NextLocation.position
        player.rotation = lastAction.NextLocation.rotation
        lastAction.path = nil
        if DEBUG then
            outputConsole("Move:Apply - getting next valid action")
        end
        lastAction.NextLocation:GetNextValidAction(lastAction.Performer):Apply()
	end
	removeEventHandler("onMarkerHit", source, destinationReached)
	source:destroy()
end

function Move:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    if self.TargetItem.Description ~= self.Performer:getData('location') then
        story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " " .. self.TargetItem.Description, self.Performer)
        self.Performer:setData('location', self.TargetItem.Description)
    end

    if DEBUG then
        outputConsole("Move:Apply")
    end

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