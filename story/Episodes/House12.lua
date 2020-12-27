House12 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, {name = 'house12'})
    o:LoadFromFile()
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

    local livingroomSofa1 = Sofa {
        modelid = Sofa.eModel.Couch02,
        position =     Vector3(2322.2266, -1142.4766, 1049.4766),
        rotation =     Vector3(0, 0.0000, 90),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Sofa.eModel.Couch02, 0.25, livingroomSofa1.position)    
    table.insert(self.Objects, livingroomSofa1)

    local livingroomSofa2 = Sofa {
        modelid = Sofa.eModel.Couch02,
        position =     Vector3(2326.5234, -1140.5703, 1049.4766),
        rotation =     Vector3(0, 0.0000, 270),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Sofa.eModel.Couch02, 0.25, livingroomSofa2.position)    
    table.insert(self.Objects, livingroomSofa2)

    local livingroomChair = Chair {
        modelid = Chair.eModel.WhiteChair,
        position =     Vector3(2314.2969, -1146.0125, 1050.3203),
        rotation =     Vector3(0, 0.0000, 270),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Chair.eModel.WhiteChair, 0.5, livingroomChair.position)    
    table.insert(self.Objects, livingroomChair)

    local livingroomTable = Table {
        modelid = Table.eModel.GlassTable,
        position =     Vector3(2314.2734, -1144.8984, 1050.0859),
        rotation =     Vector3(0, 0.0000, 270),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Table.eModel.GlassTable, 0.25, livingroomTable.position)    
    table.insert(self.Objects, livingroomTable)

    local laptop = Laptop {
        modelid = Laptop.eModel.Closed,
        position =     Vector3(2314.3234, -1145.5484, 1050.5059),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    table.insert(self.Objects, laptop)

    local kitchenSink = Furniture {
        modelid = Furniture.eModel.House10Kitchen1,
        position =     Vector3(2337.3281, -1138.1328, 1049.6719),
        rotation =     Vector3(0, 0.0000, 270),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House10Kitchen1, 0.25, kitchenSink.position)    
    table.insert(self.Objects, kitchenSink)

    local bedroom1Bed = Bed {
        modelid = Bed.eModel.SwankBed7,
        position =     Vector3(2336.5391, -1138.7891, 1053.2813),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Bed.eModel.SwankBed7, 0.25, bedroom1Bed.position)    
    table.insert(self.Objects, bedroom1Bed)

    local bedroom2Bed = Bed {
        modelid = Bed.eModel.Unknown9,
        position =     Vector3(2309.5156, -1139.3438, 1053.4219),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Bed.eModel.Unknown9, 0.25, bedroom2Bed.position)    
    table.insert(self.Objects, bedroom2Bed)
    
    local drinkId = Drinks.eModel[PickRandom(Drinks.eModel)]
    local drink1 = Drinks {
        modelid = drinkId,
        position =     Vector3(2331.306640625, -1140.846923828125, 1050.775),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    table.insert(self.Objects, drink1)


    local drink2 = Drinks {
        modelid = drinkId,
        position =     Vector3(2331.306640625, -1142.846923828125, 1050.775),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    table.insert(self.Objects, drink2)

    local livingRoomEntranceLocation = Location(2324.4219, -1147.9844, 1050.875, 0, self.InteriorId, "living room")
    local livingRoomSofa1Location = Location(2322.8051171875, -1142.068359375, 1050.875, 270, self.InteriorId, "sofa1")
    local livingRoomSofa2Location = Location(2325.9713671875, -1142.026489257813, 1050.875, 90, self.InteriorId, "sofa2")
    local livingRoomChairLocation = Location(2314.353515625, -1146.708862304688, 1050.875, 0, self.InteriorId, "chair")

    local kitchenSinkLocation = Location(2336.946220703125, -1139.029296875, 1050.875, 270, self.InteriorId, "sink")
    local kitchenTableLocation1 = Location(2331.906640625, -1140.846923828125, 1050.875, 90, self.InteriorId, "table")
    local kitchenTableLocation2 = Location(2331.906640625, -1142.846923828125, 1050.875, 90, self.InteriorId, "table again")
    local kitchenTableLocation1Back = Location(2331.906640625, -1140.846923828125, 1050.875, 90, self.InteriorId, "table again")

    -- local bedroom1EntranceLocation = Location(2334.14599609375, -1138.757934570313, 1054.3046875, 270, self.InteriorId, "bedroom")
    -- local bedroom1EntranceLocation2 = Location(2332.56298828125, -1138.757934570313, 1054.3046875, 90, self.InteriorId, "bedroom")
    -- local bedroom1ExitLocation = Location(2335.93798828125, -1138.809692382813, 1054.3046875, 90, self.InteriorId, "bedroom")
    local bedroom1BedLocation = Location(2336.332763671875, -1136.330444335938, 1054.3046875, 270, self.InteriorId, "bed")

    -- local bedroom2EntranceLocation = Location(2314.76806640625, -1138.866088867188, 1054.3046875, 90, self.InteriorId, "bedroom")
    -- local bedroom2EntranceLocation2 = Location(2315.981689453125, -1139.005859375, 1054.3046875, 270, self.InteriorId, "bedroom")
    -- local bedroom2ExitLocation = Location(2312.735107421875, -1138.976074218755, 1054.3046875, 270, self.InteriorId, "bedroom")
    local bedroom2BedLocation = Location(2310.430419921875, -1141.222900390625, 1054.3046875, 90, self.InteriorId, "bed")

    
    self.POI = {livingRoomSofa1Location, livingRoomSofa2Location, livingRoomChairLocation, kitchenTableLocation1, bedroom1BedLocation, bedroom2BedLocation, livingRoomEntranceLocation}  
    -- sit on sofa1
    local sitOnSofa1Action = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofa1Location, targetItem = livingroomSofa1, rotation = Vector3(0,0,90), graphId = self.graphId}
    table.insert(livingRoomSofa1Location.PossibleActions, sitOnSofa1Action)
    local standUpSofa1Action = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofa1Location, targetItem = livingroomSofa1, graphId = self.graphId}
    sitOnSofa1Action.NextAction = standUpSofa1Action
    sitOnSofa1Action.ClosingAction = standUpSofa1Action

    -- sit on sofa2
    local sitOnSofa2Action = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofa2Location, targetItem = livingroomSofa2, rotation = Vector3(0,0,270), graphId = self.graphId}
    table.insert(livingRoomSofa2Location.PossibleActions, sitOnSofa2Action)
    local standUpSofa2Action = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofa2Location, targetItem = livingroomSofa2, graphId = self.graphId}
    sitOnSofa2Action.NextAction = standUpSofa2Action
    sitOnSofa2Action.ClosingAction = standUpSofa2Action

    -- sit on chair
    local sitDownLivingRoomChairAction = SitDown {how = SitDown.eHow.atDesk, performer = player, nextLocation = livingRoomChairLocation, targetItem = livingroomChair, rotation = Vector3(0,0,0), graphId = self.graphId}
    table.insert(livingRoomChairLocation.PossibleActions, sitDownLivingRoomChairAction)
    local openLaptopAction = OpenLaptop{performer = player, nextLocation = livingRoomChairLocation, targetItem = laptop }
    sitDownLivingRoomChairAction.NextAction = openLaptopAction
    local writeOnLaptop = TypeOnKeyboard{performer = player, nextLocation = livingRoomChairLocation, targetItem = laptop }
    openLaptopAction.NextAction = writeOnLaptop
    local layOnElbow = LayOnElbow{performer = player, nextLocation = livingRoomChairLocation, targetItem = laptop }
    writeOnLaptop.NextAction = layOnElbow
    local writeOnLaptop2 = TypeOnKeyboard{performer = player, nextLocation = livingRoomChairLocation, targetItem = laptop }
    layOnElbow.NextAction = writeOnLaptop2
    local closeLaptopAction = CloseLaptop{performer = player, nextLocation = livingRoomChairLocation, targetItem = laptop }
    writeOnLaptop2.NextAction = closeLaptopAction
    local standUpLivingRoomChairAction = StandUp {how = StandUp.eHow.fromDesk, performer = player, nextLocation = livingRoomChairLocation, targetItem = livingroomChair, graphId = self.graphId}
    closeLaptopAction.NextAction = standUpLivingRoomChairAction
    sitDownLivingRoomChairAction.ClosingAction = standUpLivingRoomChairAction

    -- kitchen actions
    local pickUpDrinkAction = PickUp {performer = player, nextLocation = kitchenTableLocation1, targetItem = drink1, where = "the table", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(kitchenTableLocation1.PossibleActions, pickUpDrinkAction)
    local drinkAction = Drink {performer = player, nextLocation = kitchenTableLocation1, targetItem = drink1, graphId = self.graphId}
    pickUpDrinkAction.NextAction = drinkAction
    local putDownDrinkAction = PutDown {performer = player, nextLocation = kitchenTableLocation1, targetItem = drink1, where = "the table", targetObjectPosition = Vector3(2331.306640625, -1140.846923828125, 1050.775),
                                       targetObjectRotation = Vector3(0, 0, 0), graphId = self.graphId}
    drinkAction.NextAction = putDownDrinkAction
    pickUpDrinkAction.ClosingAction = putDownDrinkAction

    local washhandsKitchenSinkAction = WashHands {performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSinkLocation, graphId = self.graphId}
    table.insert(kitchenSinkLocation.PossibleActions, washhandsKitchenSinkAction)
    
    -- pick a random next table location
    math.randomseed(os.time())
    dice = math.random(1, 2)
    
    if dice == 1 then
        nextTableLocation = kitchenTableLocation1Back
        nextDrink = drink1
    else
        nextTableLocation = kitchenTableLocation2
        nextDrink = drink2
    end

    local moveToNextTableLocation = Move { performer = player, nextLocation = nextTableLocation, targetItem = nextTableLocation, graphId = self.graphId }
    washhandsKitchenSinkAction.NextAction = moveToNextTableLocation
    washhandsKitchenSinkAction.ClosingAction = moveToNextTableLocation

    local pickUpDrinkAction2 = PickUp {performer = player, nextLocation = nextTableLocation, targetItem = nextDrink, where = "the table", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(nextTableLocation.PossibleActions, pickUpDrinkAction2)
    local drinkAction2 = Drink {performer = player, nextLocation = nextTableLocation, targetItem = nextDrink, graphId = self.graphId}
    pickUpDrinkAction2.NextAction = drinkAction2
    local putDownDrinkAction2 = PutDown {performer = player, nextLocation = nextTableLocation, targetItem = nextDrink, where = "the table", targetObjectPosition = Vector3(2331.306640625, -1140.846923828125, 1050.775),
                                       targetObjectRotation = Vector3(0, 0, 0), graphId = self.graphId}
    drinkAction2.NextAction = putDownDrinkAction2
    pickUpDrinkAction2.ClosingAction = putDownDrinkAction2

    -- bedroom 1 actions
    -- local opendoorBedRoom1Location = OpenDoor { performer = player, nextLocation = bedroom1BedLocation, targetItem = bedroom1BedLocation, how = OpenDoor.eHow.Enter, graphId = self.graphId }
    -- table.insert(bedroom1EntranceLocation.PossibleActions, opendoorBedRoom1Location)

    local getInBed1Action = GetOn{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1BedLocation, how = GetOn.eHow.Bed, side = GetOn.eSide.Left, graphId = self.graphId}
    table.insert(bedroom1BedLocation.PossibleActions, getInBed1Action)
    local slee1pAction = Sleep { nextLocation = bedroom1BedLocation, performer = player, targetItem = bedroom1Bed, how = Sleep.eHow.Left, graphId = self.graphId}
    getInBed1Action.NextAction = slee1pAction
    local getOffBed1Action = GetOff{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1BedLocation,  how = GetOff.eHow.Bed, side = GetOff.eSide.Left, graphId = self.graphId}
    slee1pAction.NextAction = getOffBed1Action
    getInBed1Action.ClosingAction = getOffBed1Action
    -- local moveToBedroom1ExitAction = Move { performer = player, nextLocation = bedroom1ExitLocation, targetItem = bedroom1ExitLocation, graphId = self.graphId}
    -- getOffBed1Action.NextAction = moveToBedroom1ExitAction

    -- local openBedroom1DoorAction2 = OpenDoor {performer = player, nextLocation = bedroom1EntranceLocation2, targetItem = bedroom1EntranceLocation2, how = OpenDoor.eHow.Exit, graphId = self.graphId}
    -- table.insert(bedroom1ExitLocation.PossibleActions, openBedroom1DoorAction2)

    -- bedroom 2 actions
    -- local opendoorBedRoom2Location = OpenDoor { performer = player, nextLocation = bedroom2BedLocation, targetItem = bedroom2BedLocation, how = OpenDoor.eHow.Enter, graphId = self.graphId }
    -- table.insert(bedroom2EntranceLocation.PossibleActions, opendoorBedRoom2Location)

    local getInBed2Action =  GetOn{performer = player, targetItem = bedroom2Bed, nextLocation = bedroom2BedLocation, how = GetOn.eHow.Bed, side = GetOn.eSide.Left, graphId = self.graphId}
    table.insert(bedroom2BedLocation.PossibleActions, getInBed2Action)
    local slee2pAction = Sleep { nextLocation = bedroom2BedLocation, performer = player, targetItem = bedroom2Bed, how = Sleep.eHow.Left, graphId = self.graphId}
    getInBed2Action.NextAction = slee2pAction
    local getOffBed2Action = GetOff{performer = player, targetItem = bedroom2Bed, nextLocation = bedroom2BedLocation,  how = GetOff.eHow.Bed, side = GetOff.eSide.Left, graphId = self.graphId}
    slee2pAction.NextAction = getOffBed2Action
    getInBed2Action.ClosingAction = getOffBed2Action

    -- local openBedroom2DoorAction2 = OpenDoor {performer = player, nextLocation = bedroom2EntranceLocation2, targetItem = bedroom2EntranceLocation2, how = OpenDoor.eHow.Exit, graphId = self.graphId}
    -- table.insert(bedroom2ExitLocation.PossibleActions, openBedroom2DoorAction2)

    StoryEpisodeBase.Initialize(self, arg)

    if DEBUG then
        outputConsole("House12:Initialized")
    end
    return true
end

function House12:Destroy()
    for _, item in ipairs(self.Objects) do
        item:Destroy()
    end
    if unloadPathGraph and self.graphId then
        unloadPathGraph(self.graphId)
    end
    if DEBUG then
        outputConsole("House12:Destroyed")
    end
    StoryEpisodeBase.Destroy(self)
end