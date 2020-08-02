House1 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, nil, nil, nil)
    o.InteriorId = 1
    if not loadPathGraph then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return
    end

    -- Load path graph
    o.graphId = loadPathGraph("files/paths/house1.json")
    if not findShortestPathBetween then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return false
    end
end)

function House1:Initialize(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    local livingroomSofa = Furniture {
        modelid = Furniture.eModel.House1LivingRoom1,
        position =     Vector3(-2163.6563, 644.9063, 1058.6250),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House1LivingRoom1, 0.25, livingroomSofa.position)    
    livingroomSofa:Create()
    table.insert(self.Objects, livingroomSofa)

    local livingRoomEntranceLocation = Location(-2170.126708984375, 638.444580078125, 1057.5971, 0, self.InteriorId, "livin room")
    local livingRoomSofaLocation = Location(-2165.447412109375, 643.7353515625, 1057.5971, 0, self.InteriorId, "sofa")

    local livingRoomEndLocation = Location(-2170.126708984375, 638.444580078125, 1057.5971, 180, self.InteriorId, "livin room")

    table.insert(self.ValidStartingLocations, livingRoomSofaLocation)

    local pointsOfInterests = {livingRoomSofaLocation, livingRoomEndLocation}
    pointsOfInterests = Shuffle(pointsOfInterests)

    if pointsOfInterests[1] == livingRoomEndLocation then
        local i = math.random(#pointsOfInterests - 1) + 1
        pointsOfInterests[1], pointsOfInterests[i] = pointsOfInterests[i], pointsOfInterests[1]
    end

    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = pointsOfInterests[1], targetItem = pointsOfInterests[1], graphId = self.graphId })

    local sitOnSofaAction = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofaLocation, targetItem = livingroomSofa, rotation = Vector3(0,0,270), graphId = self.graphId}
    table.insert(livingRoomSofaLocation.PossibleActions, sitOnSofaAction)
    local standUpSofaAction = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofaLocation, targetItem = livingroomSofa, graphId = self.graphId}
    sitOnSofaAction.NextAction = standUpSofaAction
    moveToPOS2Action = Move { performer = player, nextLocation = pointsOfInterests[2], targetItem = pointsOfInterests[2], graphId = self.graphId }
    standUpSofaAction.NextAction = moveToPOS2Action
    sitOnSofaAction.ClosingAction = moveToPOS2Action

    if DEBUG then
        outputConsole("House1:Initialized")
    end
    return true
end

function House1:Play(...)
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
        outputConsole("House1:Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
end
    
function House1:Destroy()
    for item in self.Objects do
        item:Destroy()
    end
    unloadPathGraph()
    if DEBUG then
        outputConsole("House1:Destroyed")
    end
end