House3 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, nil, nil, nil)
    o.InteriorId = 3
    if not loadPathGraph then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return
    end

    -- Load path graph
    o.graphId = loadPathGraph("files/paths/house3.json")
    if not findShortestPathBetween then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return false
    end
end)

function House3:Initialize(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    local livingRoomEntranceLocation = Location(2496.0610, -1694.2596, 1014.7422, 181.8800, self.InteriorId, "livin room near door")
    local kitchenSinkLocation = Location(2500.005859375, -1709.006225585938, 1014.7422, 270.000, self.InteriorId, "the sink in the kitchen.")

    table.insert(self.ValidStartingLocations, livingRoomEntranceLocation)

    -- Go to the sink in the kitchen
    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSinkLocation, graphId = self.graphId })

    -- Wash Hands at the sink
    table.insert(kitchenSinkLocation.PossibleActions, WashHands { performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSinkLocation, graphId = self.graphId })

    if DEBUG then
        outputConsole("House3:Initialized")
    end
    return true
end

function House3:Play(...)
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
        outputConsole("House3:Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
end
    
function House3:Destroy()
    for item in self.Objects do
        item:Destroy()
    end
    unloadPathGraph()
    if DEBUG then
        outputConsole("House3:Destroyed")
    end
end