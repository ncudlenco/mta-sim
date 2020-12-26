House3 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, {name = 'house3'})
    o:LoadFromFile()

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
    
    -- declare objects

    -- create two new chairs in the kitchen

    local kitchenChair2 = Chair{
        modelid =      Chair.eModel.SolidWoodenChair,
        position =     Vector3(2494.5, -1706.7609, 1014.4422),
        rotation =     Vector3(0, 0, 0),
        noCollisions = true,
        interior =     self.InteriorId
    }
    table.insert(self.Objects, kitchenChair2)

    local livingroomRemote = Remote {
        modelid =      Remote.eModel.Remote1,
        position =     Vector3(2492.8154, -1698.0571, 1014.3103),
        rotation =     Vector3(0, 0, 0),
        noCollisions = true,
        interior =     self.InteriorId
    }
    table.insert(self.Objects, livingroomRemote)

    local livingroomSofa = Furniture {
        modelid = Furniture.eModel.House3LivingRoom1,
        position =     Vector3(2501.0703, -1697.6172, 1016.1250),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House3LivingRoom1, 10.25, livingroomSofa.position)    
    table.insert(self.Objects, livingroomSofa)

    local kitchenSink = Furniture {
        modelid = Furniture.eModel.House3Kitchen1,
        position =     Vector3(2497.8750, -1709.0703, 1015.2344),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House3Kitchen1, 10.25, kitchenSink.position)    
    table.insert(self.Objects, kitchenSink)

    local livingroomSofa1 = Sofa {
        modelid = 14477,
        position =     Vector3(2501.0703, -1697.6172, 1016.1250),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(14477, 10.25, livingroomSofa1.position)
    table.insert(self.Objects, livingroomSofa1)    

    local bedroomBed = Bed{
        modelid =      Bed.eModel.Unknown3,
        position =     Vector3(2493.2177734375, -1702.223217773438, 1017.3672),
        rotation =     Vector3(0, 0, 270),
        noCollisions = true,
        interior =     self.InteriorId
    }
    removeWorldModel(Bed.eModel.Unknown3, 5.25, bedroomBed.position)
    table.insert(self.Objects, bedroomBed)

    -- get food from the fridge
    local food = Food {
        modelid = Food.eModel[PickRandom(Food.eModel)],
        noCollisions = true,
        position =     Vector3(2493.8033, -1708.3198, 1014.7022),
        rotation =     Vector3(0, 0, 0),
        interior = self.InteriorId
    }
    table.insert(self.Objects, food)

    local plate = Plate {
        modelid = Plate.eModel.Unknown1,
        noCollisions = true,
        position =     Vector3(2493.5033, -1708.3198, 1014.6322),
        rotation =     Vector3(0, 0, 0),
        interior = self.InteriorId
    }
    table.insert(self.Objects, plate)

    local drink = Drinks {
        modelid = Drinks.eModel[PickRandom(Drinks.eModel)],
        position =     Vector3(2493.5433, -1702.5198, 1014.5922),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }
    table.insert(self.Objects, drink)

    if DEBUG then
        outputConsole("House3: Objects initialized")
    end

    local livingRoomEntranceLocation = Location(2496.212, -1694.371459, 1014.7422, 181.8800, self.InteriorId, "entrance")
    local kitchenSinkLocation = Location(2500.235859375, -1709.40225585938, 1014.7422, 270.000, self.InteriorId, "kitchen")
    local kitchenTableLocation = Location(2494.2033, -1708.3198, 1014.7422, 90, self.InteriorId, "kitchen")
    local livingroomSofaLocation = Location(2492.5772, -1699.004663085938, 1014.7422, 0, self.InteriorId, "living room")
    local livingroomTableLocation = Location(2494.0677734375, -1702.523217773438, 1014.7422, 90, self.InteriorId, "living room")
    local bedroomBedLocation = Location(2495.2177734375, -1703.923217773438, 1018.34375, 0, self.InteriorId, "bedroom")

    self.POI = {kitchenSinkLocation, kitchenTableLocation, livingroomSofaLocation, livingroomTableLocation, bedroomBedLocation, livingRoomEntranceLocation}

    -- Wash Hands at the sink
    local washHandsAction = WashHands { performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSink, graphId = self.graphId }
    table.insert(kitchenSinkLocation.PossibleActions, washHandsAction)
    local moveToTableAction = Move {performer = player, nextLocation = kitchenTableLocation, targetItem = kitchenTableLocation, graphId = self.graphId}
    washHandsAction.NextAction = moveToTableAction
    washHandsAction.ClosingAction = moveToTableAction

    local pickUpFoodAction = PickUp {performer = player, nextLocation = kitchenTableLocation, targetItem = food, where = "the table", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(kitchenTableLocation.PossibleActions, pickUpFoodAction)
    local eatFoodAction = Eat {performer = player, nextLocation = kitchenTableLocation, targetItem = food, graphId = self.graphId}
    pickUpFoodAction.NextAction = eatFoodAction
    pickUpFoodAction.ClosingAction = eatFoodAction

    -- sit on the sofa
    local pickUpLivingroomRemoteAction = PickUp {performer = player, nextLocation = livingroomSofaLocation, targetItem = livingroomRemote, where = "the table", targetObjectExists = true, how = PickUp.eHow.Down, graphId = self.graphId}
    table.insert(livingroomSofaLocation.PossibleActions, pickUpLivingroomRemoteAction)
    local sitDownLivingroomAction = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingroomSofaLocation, targetItem = livingroomSofa, rotation = Vector3(0,0,180), graphId = self.graphId}
    pickUpLivingroomRemoteAction.NextAction = sitDownLivingroomAction
    local standUpLivingroomAction = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingroomSofaLocation, targetItem = livingroomSofa, graphId = self.graphId}
    sitDownLivingroomAction.NextAction = standUpLivingroomAction
    local putDownLivingroomAction = PutDown {performer = player, nextLocation = livingroomSofaLocation, targetItem = livingroomRemote, where = "the table", targetObjectPosition = Vector3(2492.8154, -1698.0571, 1014.3103),
                                             targetObjectRotation = Vector3(0, 0, 0), how = PutDown.eHow.Down, graphId = self.graphId}
    standUpLivingroomAction.NextAction = putDownLivingroomAction
    pickUpLivingroomRemoteAction.ClosingAction = putDownLivingroomAction

    -- drink at table
    local pickUpDrinkAction = PickUp {performer = player, nextLocation = livingroomTableLocation, targetItem = drink, where = "the table", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(livingroomTableLocation.PossibleActions, pickUpDrinkAction)
    local drinkAction = Drink {performer = player, nextLocation = livingroomTableLocation, targetItem = drink, graphId = self.graphId}
    pickUpDrinkAction.NextAction = drinkAction
    local putDownDrinkAction = PutDown {performer = player, nextLocation = livingroomTableLocation, targetItem = drink, where = "the table", targetObjectPosition = Vector3(2493.5433, -1702.5198, 1014.5922),
                                        targetObjectRotation = Vector3(0, 0, 0), graphId = self.graphId}
    drinkAction.NextAction = putDownDrinkAction
    pickUpDrinkAction.ClosingAction = putDownDrinkAction

    -- get in bed
    local getInBedAction = GetOn{performer = player, targetItem = bedroomBed, nextLocation = bedroomBedLocation, how = GetOn.eHow.Bed, side = GetOn.eSide.Right, graphId = self.graphId}
    table.insert(bedroomBedLocation.PossibleActions, getInBedAction)
    local sleepAction = Sleep { nextLocation = bedroomBed, performer = player, targetItem = bedroomBed, how = Sleep.eHow.Right, graphId = self.graphId}
    getInBedAction.NextAction = sleepAction
    local getOffBedAction = GetOff{performer = player, targetItem = bedroomBed, nextLocation = bedroomBedLocation,  how = GetOff.eHow.Bed, side = GetOff.eSide.Right, graphId = self.graphId}
    sleepAction.NextAction = getOffBedAction
    getInBedAction.ClosingAction = getOffBedAction

    StoryEpisodeBase.Initialize(self, arg)

    if DEBUG then
        outputConsole("House3:Initialized")
    end
    return true
end
    
function House3:Destroy()
    for _, item in ipairs(self.Objects) do
        item:Destroy()
    end
    if unloadPathGraph and self.graphId then
        unloadPathGraph(self.graphId)
    end
    if DEBUG then
        outputConsole("House3:Destroyed")
    end
    StoryEpisodeBase.Destroy(self)
end