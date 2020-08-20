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
    
    -- declare objects

    -- create two new chairs in the kitchen

    local kitchenChair2 = Chair{
        modelid =      Chair.eModel.SolidWoodenChair,
        position =     Vector3(2494.5, -1706.7609, 1014.4422),
        rotation =     Vector3(0, 0, 0),
        noCollisions = true,
        interior =     self.InteriorId
    }
    kitchenChair2:Create()
    table.insert(self.Objects, kitchenChair2)

    local livingroomRemote = Remote {
        modelid =      Remote.eModel.Remote1,
        position =     Vector3(2492.8154, -1698.0571, 1014.3103),
        rotation =     Vector3(0, 0, 0),
        noCollisions = true,
        interior =     self.InteriorId
    }
    livingroomRemote:Create()
    table.insert(self.Objects, livingroomRemote)

    local livingroomSofa = Furniture {
        modelid = Furniture.eModel.House3LivingRoom1,
        position =     Vector3(2501.0703, -1697.6172, 1016.1250),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House3LivingRoom1, 10.25, livingroomSofa.position)    
    livingroomSofa:Create()
    table.insert(self.Objects, livingroomSofa)

    local kitchenSink = Furniture {
        modelid = Furniture.eModel.House3Kitchen1,
        position =     Vector3(2497.8750, -1709.0703, 1015.2344),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House3Kitchen1, 10.25, kitchenSink.position)    
    kitchenSink:Create()
    table.insert(self.Objects, kitchenSink)

    local livingroomSofa1 = Sofa {
        modelid = 14477,
        position =     Vector3(2501.0703, -1697.6172, 1016.1250),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(14477, 10.25, livingroomSofa1.position)    
    livingroomSofa1:Create()

    local bedroomBed = Bed{
        modelid =      Bed.eModel.Unknown3,
        position =     Vector3(2493.2177734375, -1702.223217773438, 1017.3672),
        rotation =     Vector3(0, 0, 270),
        noCollisions = true,
        interior =     self.InteriorId
    }
    removeWorldModel(Bed.eModel.Unknown3, 5.25, bedroomBed.position)
    bedroomBed:Create()
    table.insert(self.Objects, bedroomBed)

    -- get food from the fridge
    local food = Food {
        modelid = Food.eModel[PickRandom(Food.eModel)],
        noCollisions = true,
        position =     Vector3(2493.8033, -1708.3198, 1014.7022),
        rotation =     Vector3(0, 0, 0),
        interior = self.InteriorId
    }
    food:Create()
    table.insert(self.Objects, food)

    local plate = Plate {
        modelid = Plate.eModel.Unknown1,
        noCollisions = true,
        position =     Vector3(2493.5033, -1708.3198, 1014.6322),
        rotation =     Vector3(0, 0, 0),
        interior = self.InteriorId
    }
    plate:Create()
    table.insert(self.Objects, plate)

    drink = Drinks {
        modelid = Drinks.eModel[PickRandom(Drinks.eModel)],
        position =     Vector3(2493.5433, -1702.5198, 1014.5922),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    drink:Create()
    table.insert(self.Objects, drink)

    livingRoomRegion = Region({description = "living room", objects = {"table with chairs", "sofa", "TV", "flower in a pot", "comfortable with magazine"}})
    kitchenRegion = Region({description = "kitchen", objects = {"table with chairs", "fridge", "gas cooker", "microwave", "window"}})
    bedroomRegion = Region({description = "bedroom", objects = {"bed", "wardrobe", "window"}})
    exitRegion = Region({description = "exit of the house"})

    local livingRoomEntranceLocation = Location(2496.212, -1694.371459, 1014.7422, 181.8800, self.InteriorId, "entrance", livingRoomRegion)
    local kitchenSinkLocation = Location(2500.235859375, -1709.40225585938, 1014.7422, 270.000, self.InteriorId, "kitchen", kitchenRegion)
    local kitchenTableLocation = Location(2494.2033, -1708.3198, 1014.7422, 90, self.InteriorId, "kitchen", kitchenRegion)
    local livingroomSofaLocation = Location(2492.5772, -1699.004663085938, 1014.7422, 0, self.InteriorId, "living room", livingRoomRegion)
    local livingroomTableLocation = Location(2494.0677734375, -1702.523217773438, 1014.7422, 90, self.InteriorId, "living room", livingRoomRegion)
    local bedroomBedLocation = Location(2495.2177734375, -1703.923217773438, 1018.34375, 0, self.InteriorId, "bedroom", bedroomRegion)
    local livingRoomEndLocation = Location(2496.0610, -1694.2596, 1014.7422, 0, self.InteriorId, "living room exit", exitRegion)

    table.insert(self.ValidStartingLocations, livingRoomEntranceLocation)
    player:setData('location', livingRoomEntranceLocation.Description)
    player:setData('prevLocations', {})

    local pointsOfInterests = {livingroomSofaLocation, livingroomTableLocation, kitchenSinkLocation, bedroomBedLocation, livingRoomEndLocation}
    -- pointsOfInterests = Shuffle(pointsOfInterests)

    if pointsOfInterests[1] == livingRoomEndLocation then
        local i = math.random(4) + 1
        pointsOfInterests[1], pointsOfInterests[i] = pointsOfInterests[i], pointsOfInterests[1]
    end

    -- Go to the sink in the kitchen
    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = pointsOfInterests[1], targetItem = pointsOfInterests[1], graphId = self.graphId })

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
    local moveToPOS2Action = Move {performer = player, nextLocation = pointsOfInterests[2], targetItem = pointsOfInterests[2], graphId = self.graphId}
    eatFoodAction.NextAction = moveToPOS2Action
    pickUpFoodAction.ClosingAction = moveToPOS2Action

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

    local moveToPOS3Action = Move { performer = player, nextLocation = pointsOfInterests[3], targetItem = pointsOfInterests[3], graphId = self.graphId}
    putDownLivingroomAction.NextAction = moveToPOS3Action
    pickUpLivingroomRemoteAction.ClosingAction = moveToPOS3Action

    -- drink at table
    local pickUpDrinkAction = PickUp {performer = player, nextLocation = livingroomTableLocation, targetItem = drink, where = "the table", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(livingroomTableLocation.PossibleActions, pickUpDrinkAction)
    local drinkAction = Drink {performer = player, nextLocation = livingroomTableLocation, targetItem = drink, graphId = self.graphId}
    pickUpDrinkAction.NextAction = drinkAction
    local putDownDrinkAction = PutDown {performer = player, nextLocation = livingroomTableLocation, targetItem = drink, where = "the table", targetObjectPosition = Vector3(2493.5433, -1702.5198, 1014.5922),
                                        targetObjectRotation = Vector3(0, 0, 0), graphId = self.graphId}
    drinkAction.NextAction = putDownDrinkAction

    local moveToPOS4Action = Move { performer = player, nextLocation = pointsOfInterests[4], targetItem = pointsOfInterests[4], graphId = self.graphId}
    putDownDrinkAction.NextAction = moveToPOS4Action
    pickUpDrinkAction.ClosingAction = moveToPOS4Action

    -- get in bed
    local getInBedAction = GetInBed{performer = player, targetItem = bedroomBed, nextLocation = bedroomBedLocation, how = GetInBed.eHow.Right, graphId = self.graphId}
    table.insert(bedroomBedLocation.PossibleActions, getInBedAction)
    local sleepAction = Sleep { nextLocation = bedroomBed, performer = player, targetItem = bedroomBed, how = Sleep.eHow.Right, graphId = self.graphId}
    getInBedAction.NextAction = sleepAction
    local getOffBedAction = GetOffBed{performer = player, targetItem = bedroomBed, nextLocation = bedroomBedLocation, how = GetOffBed.eHow.Right, graphId = self.graphId}
    sleepAction.NextAction = getOffBedAction
    local moveToPOI5Action = Move { performer = player, nextLocation = pointsOfInterests[5], targetItem = pointsOfInterests[5], graphId = self.graphId}
    getOffBedAction.NextAction = moveToPOI5Action
    getInBedAction.ClosingAction = moveToPOI5Action

    table.insert(livingRoomEndLocation.PossibleActions, EndStory())

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