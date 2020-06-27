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
    local bedroomChair1 = Chair{
        modelid =      Chair.eModel.SolidWoodenChair,
        position =     Vector3(2494.5, -1708.3188, 1014.2422),
        rotation =     Vector3(0, 0, 0),
        noCollisions = true,
        interior =     self.InteriorId
    }
    bedroomChair1:Create()
    table.insert(self.Objects, bedroomChair1)

    local bedroomChair2 = Chair{
        modelid =      Chair.eModel.SolidWoodenChair,
        position =     Vector3(2494.5, -1706.7609, 1014.2422),
        rotation =     Vector3(0, 0, 0),
        noCollisions = true,
        interior =     self.InteriorId
    }
    bedroomChair2:Create()
    table.insert(self.Objects, bedroomChair2)

    local livingRoomEntranceLocation = Location(2496.0610, -1694.2596, 1014.7422, 181.8800, self.InteriorId, "livin room")
    local kitchenSinkLocation = Location(2500.005859375, -1709.006225585938, 1014.7422, 270.000, self.InteriorId, "the sink in the kitchen")
    local kitchenFridgeLocation = Location(2498.2986, -1711.3533, 1014.7422, 169.6598, self.InteriorId, "fridge")
    local kitchenMicroWaveLocation = Location(2500.01416, -1711.3533, 1014.7422, 270.000, self.InteriorId, "microwave")
    local kitchenChairLocation = Location(2495.2033, -1708.3198, 1014.7422, 90, self.InteriorId, "chair")
    local livingroomSofaLocation = Location(2492.9772, -1698.654663085938, 1014.7422, 0, self.InteriorId, "chair")

    table.insert(self.ValidStartingLocations, livingRoomEntranceLocation)

    -- Go to the sink in the kitchen
    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSinkLocation, graphId = self.graphId })

    -- Wash Hands at the sink
    local washHandsAction = WashHands { performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSinkLocation, graphId = self.graphId }
    table.insert(kitchenSinkLocation.PossibleActions, washHandsAction)
    local moveToFridgeAction = Move { performer = player, prerequisites = { washHandsAction }, nextLocation = kitchenFridgeLocation, targetItem = kitchenFridgeLocation, graphId = self.graphId}
    washHandsAction.NextAction = moveToFridgeAction
    washHandsAction.ClosingAction = moveToFridgeAction

    -- get food from the fridge
    local food = Food {
        modelid = Food.eModel[PickRandom(Food.eModel)],
        noCollisions = true,
        position =     Vector3(0, 0, 0),
        rotation =     Vector3(0, 0, 0),
        interior = self.InteriorId
    }
    
    local pickUpFoodAction = PickUp {performer = player, nextLocation = kitchenFridgeLocation, targetItem = food, where = "the fridge", graphId = self.graphId}
    table.insert(kitchenFridgeLocation.PossibleActions, pickUpFoodAction)
    local moveToMicroWaveAction = Move { performer = player, nextLocation = kitchenMicroWaveLocation, targetItem = kitchenMicroWaveLocation, graphId = self.graphId}
    pickUpFoodAction.NextAction = moveToMicroWaveAction
    pickUpFoodAction.ClosingAction = moveToMicroWaveAction

    -- cook food at the microwave
    local putInFoodAction = PutIn {performer = player, nextLocation = kitchenMicroWaveLocation, targetItem = food, where = "the microwave", graphId = self.graphId}
    table.insert(kitchenMicroWaveLocation.PossibleActions, putInFoodAction)
    local waitAction = Wait { performer = player, nextLocation = kitchenMicroWaveLocation, time = 3000, graphId = self.graphId}
    putInFoodAction.NextAction = waitAction
    local pickUpFoodAction = PickUp {performer = player, nextLocation = kitchenMicroWaveLocation, targetItem = food, where = "the microwave", graphId = self.graphId}
    waitAction.NextAction = pickUpFoodAction
    local moveToKitchenChairAction = Move { performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChairLocation, graphId = self.graphId}
    pickUpFoodAction.NextAction = moveToKitchenChairAction
    putInFoodAction.ClosingAction = moveToKitchenChairAction

    -- eat at the table
    local sitDownKitchenChairAction = SitDown {performer = player, nextLocation = kitchenChairLocation, targetItem = bedroomChair1, graphId = self.graphId}
    table.insert(kitchenChairLocation.PossibleActions, sitDownKitchenChairAction)
    local eatKitchenChairAction = Eat {performer = player, nextLocation = kitchenChairLocation, targetItem = food, graphId = self.graphId}
    sitDownKitchenChairAction.NextAction = eatKitchenChairAction
    local standUpKitchenChiarAction = StandUp {performer = player, nextLocation = kitchenChairLocation, targetItem = bedroomChair1, graphId = self.graphId}
    eatKitchenChairAction.NextAction = standUpKitchenChiarAction
    local moveToLivingroomSofa = Move { performer = player, nextLocation = livingroomSofaLocation, targetItem = livingroomSofaLocation, graphId = self.graphId}
    standUpKitchenChiarAction.NextAction = moveToLivingroomSofa
    sitDownKitchenChairAction.ClosingAction = moveToLivingroomSofa

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