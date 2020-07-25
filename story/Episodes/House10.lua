House10 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, nil, nil, nil)
    o.InteriorId = 10
    if not loadPathGraph then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return
    end

    -- Load path graph
    o.graphId = loadPathGraph("files/paths/house10.json")
    if not findShortestPathBetween then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return false
    end
end)

function House10:Initialize(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    local livingRoomEntranceLocation = Location(2268.8281, -1210.2188, 1047.5547, 90, self.InteriorId, "living room")
    local livingRoomSofa1Location = Location(2260.131591796875, -1212.2734375, 1049.0234375, 225, self.InteriorId, "sofa")
    local livingRoomSofa2Location = Location(2258.73193359375, -1208.598510742188, 1049.0234375, 180, self.InteriorId, "sofa")
    local livingRoomMusicPlayerLocation = Location(2261.76025390625, -1208.617553710938, 1049.0234375, 270, self.InteriorId, "music player")
    local kitchenSinkLocation = Location(2248.12060546875, -1209.934448242188, 1049.0234375, 90, self.InteriorId, "sink")
    local kitchenChairLocation = Location(2250.29248046875, -1210.2216796875, 1049.0234375, 180, self.InteriorId, "chair")
    local bedroomEntranceLocation = Location(2261.1142578125, -1218.331787109375, 1049.0234375, 180, self.InteriorId, "bedroom entrance")
    local bedroomExitLocation = Location(2261.194580078125, -1219.606567382813, 1049.0234375, 180, self.InteriorId, "bedroom exit")
    local bedroomBedLocation = Location(2259.509521484375, -1223.532592773438, 1049.0234375, 180, self.InteriorId, "bedroom bed")
    local livingRoomEndLocation = Location(2268.8281, -1210.2188, 1047.5547, 270, self.InteriorId, "end")

    table.insert(self.ValidStartingLocations, livingRoomEntranceLocation)

    local pointsOfInterests = {livingRoomSofa1Location, livingRoomSofa2Location, livingRoomMusicPlayerLocation, kitchenSinkLocation, bedroomEntranceLocation, livingRoomEndLocation}
    pointsOfInterests = Shuffle(pointsOfInterests)

    if pointsOfInterests[1] == livingRoomEndLocation then
        local i = math.random(5) + 1
        pointsOfInterests[1], pointsOfInterests[i] = pointsOfInterests[i], pointsOfInterests[1]
    end

    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = pointsOfInterests[1], targetItem = pointsOfInterests[1], graphId = self.graphId })

    if DEBUG then
        outputConsole("House10:Initialized")
    end
    return true
end

function House10:Play(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    if self.StartingLocation == nil then
        self.StartingLocation = PickRandom(self.ValidStartingLocations)
    end
    self.StartingLocation:SpawnPlayerHere(player)
    if DEBUG then
        outputConsole("House10:Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
end
    
function House10:Destroy()
    for item in self.Objects do
        item:Destroy()
    end
    unloadPathGraph()
    if DEBUG then
        outputConsole("House10:Destroyed")
    end
end
