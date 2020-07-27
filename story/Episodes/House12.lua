House12 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, nil, nil, nil)
    o.InteriorId = 12
    if not loadPathGraph then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return
    end

    -- Load path graph
    o.graphId = loadPathGraph("files/paths/house12.json")
    if not findShortestPathBetween then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return false
    end
end)

function House12:Initialize(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    livingroomSofa1 = Sofa {
        modelid = Sofa.eModel.Couch02,
        position =     Vector3(2322.2266, -1142.4766, 1049.4766),
        rotation =     Vector3(0, 0.0000, 90),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Sofa.eModel.Couch02, 0.25, livingroomSofa1.position)    
    livingroomSofa1:Create()
    table.insert(self.Objects, livingroomSofa1)

    livingroomSofa2 = Sofa {
        modelid = Sofa.eModel.Couch02,
        position =     Vector3(2326.5234, -1140.5703, 1049.4766),
        rotation =     Vector3(0, 0.0000, 270),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Sofa.eModel.Couch02, 0.25, livingroomSofa2.position)    
    livingroomSofa2:Create()
    table.insert(self.Objects, livingroomSofa2)

    livingroomChair = Chair {
        modelid = Chair.eModel.WhiteChair,
        position =     Vector3(2314.2969, -1146.1125, 1050.3203),
        rotation =     Vector3(0, 0.0000, 270),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Chair.eModel.WhiteChair, 0.25, livingroomChair.position)    
    livingroomChair:Create()
    table.insert(self.Objects, livingroomChair)

    local livingRoomEntranceLocation = Location(2324.4219, -1147.9844, 1050.875, 0, self.InteriorId, "living room")
    local livingRoomSofa1Location = Location(2322.8051171875, -1142.068359375, 1050.875, 270, self.InteriorId, "sofa1")
    local livingRoomSofa2Location = Location(2325.9713671875, -1142.026489257813, 1050.875, 90, self.InteriorId, "sofa2")
    local livingRoomChairLocation = Location(2314.353515625, -1146.808862304688, 1050.875, 0, self.InteriorId, "chair")

    local livingRoomEndLocation = Location(2324.4219, -1147.9844, 1050.875, 180, self.InteriorId, "end")

    table.insert(self.ValidStartingLocations, livingRoomChairLocation)

    local pointsOfInterests = {livingRoomSofa1Location, livingRoomSofa2Location, livingRoomChairLocation, livingRoomEndLocation}
    pointsOfInterests = Shuffle(pointsOfInterests)

    if pointsOfInterests[1] == livingRoomEndLocation then
        local i = math.random(#pointsOfInterests - 1) + 1
        pointsOfInterests[1], pointsOfInterests[i] = pointsOfInterests[i], pointsOfInterests[1]
    end

    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = pointsOfInterests[1], targetItem = pointsOfInterests[1], graphId = self.graphId })
    
    -- sit on sofa1
    local sitOnSofa1Action = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofa1Location, targetItem = livingroomSofa1, rotation = Vector3(0,0,90), graphId = self.graphId}
    table.insert(livingRoomSofa1Location.PossibleActions, sitOnSofa1Action)
    local standUpSofa1Action = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofa1Location, targetItem = livingroomSofa1, graphId = self.graphId}
    sitOnSofa1Action.NextAction = standUpSofa1Action
    local  moveToPOS3Action = Move { performer = player, nextLocation = pointsOfInterests[2], targetItem = pointsOfInterests[2], graphId = self.graphId }
    standUpSofa1Action.NextAction = moveToPOS3Action
    sitOnSofa1Action.ClosingAction = moveToPOS3Action

    -- sit on sofa2
    local sitOnSofa2Action = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofa2Location, targetItem = livingroomSofa2, rotation = Vector3(0,0,270), graphId = self.graphId}
    table.insert(livingRoomSofa2Location.PossibleActions, sitOnSofa2Action)
    local standUpSofa2Action = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofa2Location, targetItem = livingroomSofa2, graphId = self.graphId}
    sitOnSofa2Action.NextAction = standUpSofa2Action
    moveToPOS3Action = Move { performer = player, nextLocation = pointsOfInterests[3], targetItem = pointsOfInterests[3], graphId = self.graphId }
    standUpSofa2Action.NextAction = moveToPOS3Action
    sitOnSofa2Action.ClosingAction = moveToPOS3Action

    -- sit on chair
    local sitDownLivingRoomChairAction = SitDown {how = SitDown.eHow.atDesk, performer = player, nextLocation = livingRoomChairLocation, targetItem = livingroomChair, rotation = Vector3(0,0,0), graphId = self.graphId}
    table.insert(livingRoomChairLocation.PossibleActions, sitDownLivingRoomChairAction)
    local standUpLivingRoomChairAction = StandUp {how = StandUp.eHow.fromDesk, performer = player, nextLocation = livingRoomChairLocation, targetItem = livingroomChair, graphId = self.graphId}
    sitDownLivingRoomChairAction.NextAction = standUpLivingRoomChairAction
    local moveToPOS4Action = Move { performer = player, nextLocation = pointsOfInterests[4], targetItem = pointsOfInterests[4], graphId = self.graphId }
    standUpLivingRoomChairAction.NextAction = moveToPOS4Action
    sitDownLivingRoomChairAction.ClosingAction = moveToPOS4Action

    if DEBUG then
        outputConsole("House12:Initialized")
    end
    return true
end

function House12:Play(...)
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
        outputConsole("House12:Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
end
    
function House12:Destroy()
    for item in self.Objects do
        item:Destroy()
    end
    unloadPathGraph()
    if DEBUG then
        outputConsole("House12:Destroyed")
    end
end