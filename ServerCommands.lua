local Timer = Timer
local Guid = Guid
local Team = Team

addCommandHandler("sit",
	function (thePlayer)
		if not thePlayer:getData("sitting") then
			thePlayer:setAnimation("int_office", "off_sit_in", -1, false, true, false, true)
			thePlayer:setData("sitting", true)
		else
			-- If you use again this command then your character stand up
			thePlayer:setAnimation()
			thePlayer:removeData("sitting")
		end
	end
)

addCommandHandler("animation",
	function (thePlayer, commandName, lib, name, loop)
		if loop == "true" then
			loop = true
		else
			loop = false
		end
		thePlayer:setAnimation(lib, name, -1, loop, true, false, true)
	end
)

addCommandHandler("clearanims", function(thePlayer)
	thePlayer:setAnimation()
end)

addCommandHandler("eat",
	function (thePlayer)
		if not thePlayer:getData("eating") then
			thePlayer:setAnimation("INT_OFFICE", "OFF_Sit_Type_Loop", -1, false, true, false, true)
			thePlayer:setData("eating", true)
		else
			-- If you use again this command then your character stand up
			thePlayer:setAnimation()
			thePlayer:removeData("eating")
		end
	end
)

addCommandHandler("getInBed",
	function (thePlayer)
		if not thePlayer:getData("sleeping") then
			thePlayer:setAnimation("INT_HOUSE", "BED_In_L", -1, false, true, false, true)
			thePlayer:setData("sleeping", true)
		else
			-- If you use again this command then your character stand up
			thePlayer:setAnimation("INT_HOUSE", "BED_Out_L", -1, false, true, false, true)
			thePlayer:removeData("sleeping")
		end
	end
)

addCommandHandler("getCar",
	function (thePlayer)
		local RaceVehicle = Vehicle ( 411, 0, 0, 0 ) 
		RaceVehicle:spawn(thePlayer.position.x+3, thePlayer.position.y+3, thePlayer.position.z)
	end
)

addCommandHandler("position",
	function (thePlayer)
		outputConsole("Position: "..thePlayer.position.x .. ", "..thePlayer.position.y..", "..thePlayer.position.z)
	end
)

addCommandHandler("teleport",
	function (thePlayer)
		local gantonHouse = Location(2495.0720, -1687.5278, 13.5150, 360, 0, " front of the house ");
		gantonHouse:SpawnPlayerHere(thePlayer)
	end
)

local path = {}
function destinationReached(player, matchingDimension)
	if path and DEBUG then
		outputConsole("Player "..player.name.." reached marker "..source:getData("idx").." / "..#path)
	end
	if (path and source:getData("idx") + 1 <= #path) then
		local idx = source:getData("idx") + 1
		if DEBUG then
			outputConsole("Moving to "..idx)
		end
		local marker = Marker(path[idx][1], path[idx][2], path[idx][3], "cylinder", 1.5, 0, 0, 0, 0)
		marker:setData("idx", idx)
		marker.interior = player.interior
		addEventHandler("onMarkerHit", marker, destinationReached)
		player:setRotation(0,0,findRotation(player.position.x, player.position.y, path[idx][1], path[idx][2]))
	else
		if DEBUG then
			outputConsole("Destination reached")
		end

		-- timer = Timer(function()
		-- 	local distance = (marker.position - player.position).length
		-- 	outputConsole("Distance "..distance)

		-- 	if math.abs(distance) <= 1.3 then
		-- 		timer:destroy()
				player:setAnimation()
				path = nil		
		-- 	end
		-- end, 100, 0)	
	end
	removeEventHandler("onMarkerHit", source, destinationReached)
	source:destroy()
end
local debugMarkers = {}
local pathFindingTarget = nil
addCommandHandler("pathfinding",
	function (player, commandName, param1)
		if param1 == "settarget" then
			pathFindingTarget = Vector3(player.position.x, player.position.y, player.position.z - 1)
			local targetMarker = Marker(pathFindingTarget, "cylinder", 1.5, 0, 0, 255, 255)
			targetMarker.interior = player.interior
			table.insert(debugMarkers, targetMarker)
		elseif param1 == "start" then
			path = {}
			if not pathFindingTarget then
				outputConsole("Set pathfinding target first. Ex: pathfinding settarget")
				return
			end
			for _, marker in pairs ( debugMarkers ) do
				if marker then
					marker:destroy()
				end
			end
			-- Check if module is loaded
			if not loadPathGraph then
				outputDebugString("Pathfinding module not loaded. Exiting...", 2)
				return
			end
	
			-- Load path graph
			local graphId = loadPathGraph("files/paths/house8.json")
			if not findShortestPathBetween then
				return false
			end
			findShortestPathBetween(
				graphId, 
				player.position.x, player.position.y, player.position.z, 
				pathFindingTarget.x, pathFindingTarget.y, pathFindingTarget.z, 
				function(result)
					if (result) then
						path = result
						table.insert(path, {pathFindingTarget.x, pathFindingTarget.y, pathFindingTarget.z})
						local nextPos = path[1]
						local marker = Marker(nextPos[1], nextPos[2], nextPos[3], "cylinder", 1.5, 0, 0, 0, 0)
						marker.interior = player.interior
						marker:setData("idx", 1)
						addEventHandler("onMarkerHit", marker, destinationReached)
	
						player:setRotation(0,0,findRotation(player.position.x, player.position.y, nextPos[1], nextPos[2]))
						player:setAnimation("ped", "WALK_civi", -1, true, true, true, true)
	
						if DEBUG then
							for _, nextPos in ipairs(result) do
								local debugMarker = Marker(nextPos[1], nextPos[2], nextPos[3], "cylinder", 1.5, 255, 0, 0, 128)
								debugMarker.interior = player.interior
								table.insert(debugMarkers, debugMarker)
							end
						end
					end
				end)
		end
	end
)