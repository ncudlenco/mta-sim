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

    livingroomSofa1 = Sofa {
        modelid = Sofa.eModel.Couch01,
        position =     Vector3(2261.4609, -1212.0625, 1048.0078),
        rotation =     Vector3(0, 0.0000, 225),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Sofa.eModel.Couch01, 0.25, livingroomSofa1.position)    
    livingroomSofa1:Create()
    table.insert(self.Objects, livingroomSofa1)

    livingroomSofa2 = Sofa {
        modelid = Sofa.eModel.Couch01,
        position =     Vector3(2257.6172, -1207.7266, 1048.0078),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Sofa.eModel.Couch01, 0.25, livingroomSofa2.position)    
    livingroomSofa2:Create()
    table.insert(self.Objects, livingroomSofa2)

    local livingRoomEntranceLocation = Location(2268.8281, -1210.2188, 1047.5547, 90, self.InteriorId, "living room")
    local livingRoomSofa1Location = Location(2260.131591796875, -1212.724375, 1049.0234375, 45, self.InteriorId, "sofa")
    local livingRoomSofa2Location = Location(2258.73193359375, -1208.188510742188, 1049.0234375, 180, self.InteriorId, "sofa")
    local livingRoomMusicPlayerLocation = Location(2261.76025390625, -1208.617553710938, 1049.0234375, 270, self.InteriorId, "music player")
    local kitchenSinkLocation = Location(2248.12060546875, -1209.934448242188, 1049.0234375, 90, self.InteriorId, "sink")
    local kitchenChairLocation = Location(2250.29248046875, -1210.2216796875, 1049.0234375, 180, self.InteriorId, "chair")
    local bedroomEntranceLocation = Location(2261.1142578125, -1218.331787109375, 1049.0234375, 180, self.InteriorId, "bedroom entrance")
    local bedroomExitLocation = Location(2261.194580078125, -1219.606567382813, 1049.0234375, 180, self.InteriorId, "bedroom exit")
    local bedroomBedLocation = Location(2259.509521484375, -1223.532592773438, 1049.0234375, 180, self.InteriorId, "bedroom bed")
    local livingRoomEndLocation = Location(2268.8281, -1210.2188, 1047.5547, 270, self.InteriorId, "end")

    table.insert(self.ValidStartingLocations, livingRoomSofa1Location)

    local pointsOfInterests = {livingRoomSofa1Location, livingRoomSofa2Location, livingRoomMusicPlayerLocation, kitchenSinkLocation, bedroomEntranceLocation, livingRoomEndLocation}
    pointsOfInterests = Shuffle(pointsOfInterests)

    if pointsOfInterests[1] == livingRoomEndLocation then
        local i = math.random(5) + 1
        pointsOfInterests[1], pointsOfInterests[i] = pointsOfInterests[i], pointsOfInterests[1]
    end

    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = pointsOfInterests[1], targetItem = pointsOfInterests[1], graphId = self.graphId })
    
    sitOnSofa1Action = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofa1Location, targetItem = livingroomSofa1, rotation = Vector3(0,0,225), graphId = self.graphId}
    table.insert(livingRoomSofa1Location.PossibleActions, sitOnSofa1Action)
    standUpSofa1Action = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofa1Location, targetItem = livingroomSofa1, graphId = self.graphId}
    sitOnSofa1Action.NextAction = standUpSofa1Action
    moveToPOS3Action = Move { performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSinkLocation, graphId = self.graphId }
    standUpSofa1Action.NextAction = moveToPOS3Action
    sitOnSofa1Action.ClosingAction = moveToPOS3Action

    sitOnSofa2Action = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofa2Location, targetItem = livingroomSofa2, rotation = Vector3(0,0,0), graphId = self.graphId}
    table.insert(livingRoomSofa2Location.PossibleActions, sitOnSofa2Action)
    standUpSofa2Action = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofa2Location, targetItem = livingroomSofa2, graphId = self.graphId}
    sitOnSofa2Action.NextAction = standUpSofa2Action
    moveToPOS3Action = Move { performer = player, nextLocation = pointsOfInterests[3], targetItem = pointsOfInterests[3], graphId = self.graphId }
    standUpSofa2Action.NextAction = moveToPOS3Action
    sitOnSofa2Action.ClosingAction = moveToPOS3Action

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
