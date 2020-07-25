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

    local livingRoomEntranceLocation = Location(2496.212, -1694.371459, 1014.7422, 181.8800, self.InteriorId, "livin room")

    table.insert(self.ValidStartingLocations, livingRoomEntranceLocation)

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
