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

    kitchenSink = Furniture {
        modelid = Furniture.eModel.House10Kitchen1,
        position =     Vector3(2337.3281, -1138.1328, 1049.6719),
        rotation =     Vector3(0, 0.0000, 270),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House10Kitchen1, 0.25, kitchenSink.position)    
    kitchenSink:Create()
    table.insert(self.Objects, kitchenSink)

    bedroom1Bed = Bed {
        modelid = Bed.eModel.SwankBed7,
        position =     Vector3(2336.5391, -1138.7891, 1053.2813),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Bed.eModel.SwankBed7, 0.25, bedroom1Bed.position)    
    bedroom1Bed:Create()
    table.insert(self.Objects, bedroom1Bed)

    bedroom2Bed = Bed {
        modelid = Bed.eModel.Unknown9,
        position =     Vector3(2309.5156, -1139.3438, 1053.4219),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Bed.eModel.Unknown9, 0.25, bedroom2Bed.position)    
    bedroom2Bed:Create()
    table.insert(self.Objects, bedroom2Bed)

    drink = Drinks {
        modelid = Drinks.eModel.CoffeCup,
        position =     Vector3(2331.306640625, -1140.846923828125, 1050.775),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    drink:Create()
    table.insert(self.Objects, drink)

    local livingRoomEntranceLocation = Location(2324.4219, -1147.9844, 1050.875, 0, self.InteriorId, "living room")
    local livingRoomSofa1Location = Location(2322.8051171875, -1142.068359375, 1050.875, 270, self.InteriorId, "sofa1")
    local livingRoomSofa2Location = Location(2325.9713671875, -1142.026489257813, 1050.875, 90, self.InteriorId, "sofa2")
    local livingRoomChairLocation = Location(2314.353515625, -1146.708862304688, 1050.875, 0, self.InteriorId, "chair")

    local kitchenSinkLocation = Location(2336.946220703125, -1139.029296875, 1050.875, 270, self.InteriorId, "sink")
    local kitchenTableLocation = Location(2331.906640625, -1140.846923828125, 1050.875, 90, self.InteriorId, "table")

    local bedroom1EntranceLocation = Location(2334.14599609375, -1138.757934570313, 1054.3046875, 270, self.InteriorId, "bedroom")
    local bedroom1EntranceLocation2 = Location(2332.56298828125, -1138.757934570313, 1054.3046875, 90, self.InteriorId, "bedroom")
    local bedroom1ExitLocation = Location(2335.93798828125, -1138.809692382813, 1054.3046875, 90, self.InteriorId, "bedroom")
    local bedroom1BedLocation = Location(2336.332763671875, -1136.330444335938, 1054.3046875, 270, self.InteriorId, "bed")

    local bedroom2EntranceLocation = Location(2314.76806640625, -1138.866088867188, 1054.3046875, 90, self.InteriorId, "bedroom")
    local bedroom2EntranceLocation2 = Location(2315.981689453125, -1139.005859375, 1054.3046875, 270, self.InteriorId, "bedroom")
    local bedroom2ExitLocation = Location(2312.735107421875, -1138.976074218755, 1054.3046875, 270, self.InteriorId, "bedroom")
    local bedroom2BedLocation = Location(2310.430419921875, -1141.222900390625, 1054.3046875, 90, self.InteriorId, "bed")

    local livingRoomEndLocation = Location(2324.4219, -1147.9844, 1050.875, 180, self.InteriorId, "end")

    table.insert(self.ValidStartingLocations, kitchenTableLocation)

    local pointsOfInterests = {livingRoomSofa1Location, livingRoomSofa2Location, livingRoomChairLocation, kitchenSinkLocation, bedroom1EntranceLocation, bedroom2EntranceLocation, livingRoomEndLocation}
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

    --kitchen
    local washhandsKitchenSinkAction = WashHands {performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSinkLocation, graphId = self.graphId}
    table.insert(kitchenSinkLocation.PossibleActions, washhandsKitchenSinkAction)
    local moveToKitchenTableAction = Move { performer = player, nextLocation = kitchenTableLocation, targetItem = kitchenTableLocation, graphId = self.graphId }
    washhandsKitchenSinkAction.NextAction = moveToKitchenTableAction
    washhandsKitchenSinkAction.ClosingAction = moveToKitchenTableAction

    local pickUpDrinkAction = PickUp {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, where = "the table", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(kitchenTableLocation.PossibleActions, pickUpDrinkAction)
    local drinkAction = Drink {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, graphId = self.graphId}
    pickUpDrinkAction.NextAction = drinkAction
    local putDownDrinkAction = PutDown {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, where = "the table", targetObjectPosition = Vector3(2331.306640625, -1140.846923828125, 1050.775),
                                        targetObjectRotation = Vector3(0, 0, 0), graphId = self.graphId}
    drinkAction.NextAction = putDownDrinkAction

    local moveToPOS5Action = Move { performer = player, nextLocation = pointsOfInterests[5], targetItem = pointsOfInterests[5], graphId = self.graphId}
    putDownDrinkAction.NextAction = moveToPOS5Action
    pickUpDrinkAction.ClosingAction = moveToPOS5Action

    -- bedroom 1 actions
    local opendoorBedRoom1Location = OpenDoor { performer = player, nextLocation = bedroom1BedLocation, targetItem = bedroom1BedLocation, graphId = self.graphId }
    table.insert(bedroom1EntranceLocation.PossibleActions, opendoorBedRoom1Location)

    local getInBed1Action = GetInBed{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1BedLocation, how = GetInBed.eHow.Left, graphId = self.graphId}
    table.insert(bedroom1BedLocation.PossibleActions, getInBed1Action)
    local slee1pAction = Sleep { nextLocation = bedroom1BedLocation, performer = player, targetItem = bedroom1Bed, how = Sleep.eHow.Left, graphId = self.graphId}
    getInBed1Action.NextAction = slee1pAction
    local getOffBed1Action = GetOffBed{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1BedLocation, how = GetOffBed.eHow.Left, graphId = self.graphId}
    slee1pAction.NextAction = getOffBed1Action
    local moveToBedroom1ExitAction = Move { performer = player, nextLocation = bedroom1ExitLocation, targetItem = bedroom1ExitLocation, graphId = self.graphId}
    getOffBed1Action.NextAction = moveToBedroom1ExitAction
    getInBed1Action.ClosingAction = moveToBedroom1ExitAction

    local openBedroom1DoorAction2 = OpenDoor {performer = player, nextLocation = bedroom1EntranceLocation2, targetItem = bedroom1EntranceLocation2, graphId = self.graphId}
    table.insert(bedroom1ExitLocation.PossibleActions, openBedroom1DoorAction2)
    
    local moveToPOS6Action = Move { performer = player, nextLocation = pointsOfInterests[6], targetItem = pointsOfInterests[6], graphId = self.graphId}
    table.insert(bedroom1EntranceLocation2.PossibleActions, moveToPOS6Action)

    -- bedroom 2 actions
    local opendoorBedRoom2Location = OpenDoor { performer = player, nextLocation = bedroom2BedLocation, targetItem = bedroom2BedLocation, graphId = self.graphId }
    table.insert(bedroom2EntranceLocation.PossibleActions, opendoorBedRoom2Location)

    local getInBed2Action = GetInBed{performer = player, targetItem = bedroom2Bed, nextLocation = bedroom2BedLocation, how = GetInBed.eHow.Left, graphId = self.graphId}
    table.insert(bedroom2BedLocation.PossibleActions, getInBed2Action)
    local slee2pAction = Sleep { nextLocation = bedroom2BedLocation, performer = player, targetItem = bedroom2Bed, how = Sleep.eHow.Left, graphId = self.graphId}
    getInBed2Action.NextAction = slee2pAction
    local getOffBed2Action = GetOffBed{performer = player, targetItem = bedroom2Bed, nextLocation = bedroom2BedLocation, how = GetOffBed.eHow.Left, graphId = self.graphId}
    slee2pAction.NextAction = getOffBed2Action
    local moveToBedroom2ExitAction = Move { performer = player, nextLocation = bedroom2ExitLocation, targetItem = bedroom2ExitLocation, graphId = self.graphId}
    getOffBed2Action.NextAction = moveToBedroom2ExitAction
    getInBed2Action.ClosingAction = moveToBedroom2ExitAction

    local openBedroom2DoorAction2 = OpenDoor {performer = player, nextLocation = bedroom2EntranceLocation2, targetItem = bedroom2EntranceLocation2, graphId = self.graphId}
    table.insert(bedroom2ExitLocation.PossibleActions, openBedroom2DoorAction2)
    
    local moveToPOS6Action = Move { performer = player, nextLocation = pointsOfInterests[7], targetItem = pointsOfInterests[7], graphId = self.graphId}
    table.insert(bedroom2EntranceLocation2.PossibleActions, moveToPOS6Action)

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