House1 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, {name = 'house1'})
    o:LoadFromFile()
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

    local musicPlayer = MusicPlayer {
        modelid = MusicPlayer.eModel.Unknown01,
        position =     Vector3(-2166.2344, 640.9297, 1056.6781),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(MusicPlayer.eModel.Unknown01, 0.25, musicPlayer.position)    
    musicPlayer:Create()
    table.insert(self.Objects, musicPlayer)

    local kitchenChair = Furniture {
        modelid = Furniture.eModel.House1LivingRoom2,
        position =     Vector3(-2160.2031, 640.8516, 1058.6016),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House1LivingRoom2, 0.25, kitchenChair.position)    
    kitchenChair:Create()
    table.insert(self.Objects, kitchenChair)

    local kitchenBook = Book {
        modelid = Book.eModel.Book1,
        position =     Vector3(-2160.3831, 643.5516, 1057.3916),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }
   
    kitchenBook:Create()
    table.insert(self.Objects, kitchenBook)
    
    local drink = Drinks {
        modelid = Drinks.eModel[PickRandom(Drinks.eModel)],
        position =     Vector3(-2162.421044921875, 639.2874145507813, 1057.5271),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    drink:Create()
    table.insert(self.Objects, drink)

    local cigarette = Cigarette {
        modelid = Cigarette.eModel.Cigarette1,
        position =     Vector3(0, 0, 0),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    local livingRoomEntranceLocation = Location(-2170.126708984375, 638.444580078125, 1057.5971, 0, self.InteriorId, "living room")
    local livingRoomSofaLocation = Location(-2165.447412109375, 643.7353515625, 1057.5971, 0, self.InteriorId, "living room")
    local livingRoomMusicPlayerLocation = Location(-2166.1552734375, 641.7701416015625, 1057.5971, 180, self.InteriorId, "living room")
    local livingRoomMusicPlayerLocation2 = Location(-2166.1552734375, 642.8620361328125, 1057.5971, 180, self.InteriorId, "living room")
    local livingRoomSmokeLocation = Location(-2164.91796875, 646.1671142578125, 1057.5971, 0, self.InteriorId, "living room")
    
    local kitchenChairLocation = Location(-2160.218017578125, 642.3208129882813, 1057.5971, 0, self.InteriorId, "kitchen")
    local kitchenTableLocation = Location(-2161.821044921875, 639.2874145507813, 1057.5971, 90, self.InteriorId, "kitchen")

    local livingRoomEndLocation = Location(-2170.126708984375, 638.444580078125, 1057.5971, 180, self.InteriorId, "house exit")

    
    self.POI = {livingRoomSofaLocation, livingRoomMusicPlayerLocation, kitchenChairLocation, kitchenTableLocation, livingRoomSmokeLocation, livingRoomEndLocation, livingRoomEntranceLocation}
    table.insert(self.ValidStartingLocations, livingRoomEntranceLocation)
    self.POI = Shuffle(self.POI)

    if self.POI[1] == livingRoomEndLocation then
        local i = math.random(#self.POI - 1) + 1
        self.POI[1], self.POI[i] = self.POI[i], self.POI[1]
    end

    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = self.POI[1], targetItem = self.POI[1], graphId = self.graphId })

    -- sit on sofa
    local sitOnSofaAction = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofaLocation, targetItem = livingroomSofa, rotation = Vector3(0,0,270), graphId = self.graphId}
    table.insert(livingRoomSofaLocation.PossibleActions, sitOnSofaAction)
    local standUpSofaAction = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofaLocation, targetItem = livingroomSofa, graphId = self.graphId}
    sitOnSofaAction.NextAction = standUpSofaAction
    moveToPOI2Action = Move { performer = player, nextLocation = self.POI[2], targetItem = self.POI[2], graphId = self.graphId }
    standUpSofaAction.NextAction = moveToPOI2Action
    sitOnSofaAction.ClosingAction = moveToPOI2Action

    -- dance at the music player
    local turnOnTurnTableAction = TurnOn { performer = player, nextLocation = livingRoomMusicPlayerLocation, targetItem = musicPlayer, graphId = self.graphId }
    table.insert(livingRoomMusicPlayerLocation.PossibleActions, turnOnTurnTableAction)
    local moveToTurnTable2Action = Move { performer = player, nextLocation = livingRoomMusicPlayerLocation2, targetItem = livingRoomMusicPlayerLocation2, graphId = self.graphId }
    turnOnTurnTableAction.NextAction = moveToTurnTable2Action
    local danceTurnTableAction = Dance { performer = player, nextLocation = livingRoomMusicPlayerLocation2, targetItem = livingRoomMusicPlayerLocation2, graphId = self.graphId }
    table.insert(livingRoomMusicPlayerLocation2.PossibleActions, danceTurnTableAction)
    local moveToTurnTable3Action = Move { performer = player, nextLocation = livingRoomMusicPlayerLocation, targetItem = livingRoomMusicPlayerLocation, graphId = self.graphId }
    danceTurnTableAction.NextAction = moveToTurnTable3Action
    local turnOffTurnTableAction = TurnOff { performer = player, nextLocation = livingRoomMusicPlayerLocation, targetItem = musicPlayer, graphId = self.graphId }
    moveToTurnTable3Action.NextAction = turnOffTurnTableAction
    local moveToPOI3Action = Move { performer = player, nextLocation = self.POI[3], targetItem = self.POI[3], graphId = self.graphId }
    turnOffTurnTableAction.NextAction = moveToPOI3Action
    turnOffTurnTableAction.ClosingAction = moveToPOI3Action

    -- sit in the chair
    local sitDownKitchenChairAction = SitDown {how = SitDown.eHow.atDesk, performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChair, rotation = Vector3(0,0,0), graphId = self.graphId}
    table.insert(kitchenChairLocation.PossibleActions, sitDownKitchenChairAction)
    local readKitchenChairAction = Read { performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenBook, graphId = self.graphId }
    sitDownKitchenChairAction.NextAction = readKitchenChairAction
    local standUpKitchenChairAction = StandUp {how = StandUp.eHow.fromDesk, performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChair, graphId = self.graphId}
    readKitchenChairAction.NextAction = standUpKitchenChairAction
    local moveToPOI4Action = Move { performer = player, nextLocation = self.POI[4], targetItem = self.POI[4], graphId = self.graphId }
    standUpKitchenChairAction.NextAction = moveToPOI4Action
    sitDownKitchenChairAction.ClosingAction = moveToPOI4Action

    -- drink at table
    local pickUpDrinkAction = PickUp {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, where = "the table", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(kitchenTableLocation.PossibleActions, pickUpDrinkAction)
    local drinkAction = Drink {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, graphId = self.graphId}
    pickUpDrinkAction.NextAction = drinkAction
    local putDownDrinkAction = PutDown {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, where = "the table", targetObjectPosition = Vector3(-2162.421044921875, 639.2874145507813, 1057.5271),
                                        targetObjectRotation = Vector3(0, 0, 0), graphId = self.graphId}
    drinkAction.NextAction = putDownDrinkAction

    local moveToPOI5Action = Move { performer = player, nextLocation = self.POI[5], targetItem = self.POI[5], graphId = self.graphId}
    putDownDrinkAction.NextAction = moveToPOI5Action
    pickUpDrinkAction.ClosingAction = moveToPOI5Action

    -- smoke at painting
    local livingroomSmokeInAction = SmokeIn { performer = player, nextLocation = livingRoomSmokeLocation, targetItem = cigarette, graphId = self.graphId }
    table.insert(livingRoomSmokeLocation.PossibleActions, livingroomSmokeInAction)
    local livingroomSmokeAction = Smoke { performer = player, nextLocation = livingRoomSmokeLocation, targetItem = cigarette, graphId = self.graphId }
    livingroomSmokeInAction.NextAction = livingroomSmokeAction
    local livingroomSmokeOutAction = SmokeOut { performer = player, nextLocation = livingRoomSmokeLocation, targetItem = cigarette, graphId = self.graphId }
    livingroomSmokeAction.NextAction = livingroomSmokeOutAction

    local moveToPOI6Action = Move { performer = player, nextLocation = self.POI[6], targetItem = self.POI[6], graphId = self.graphId}
    livingroomSmokeOutAction.NextAction = moveToPOI6Action
    livingroomSmokeInAction.ClosingAction = moveToPOI6Action

    table.insert(livingRoomEndLocation.PossibleActions, EndStory())

    StoryEpisodeBase.Initialize(self, arg)

    if DEBUG then
        outputConsole("House1:Initialized")
    end
    return true
end

function House1:Play(...)
    StoryEpisodeBase.ProcessRegions(self)
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
    for _, item in ipairs(self.Objects) do
        item:Destroy()
    end
    if unloadPathGraph and self.graphId then
        unloadPathGraph(self.graphId)
    end
    if DEBUG then
        outputConsole("House1:Destroyed")
    end
    StoryEpisodeBase.Destroy(self)
end