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

    removeWorldModel(Book.eModel.Book1, 0.25, kitchenBook.position)    
    kitchenBook:Create()
    table.insert(self.Objects, kitchenBook)
    
    drink = Drinks {
        modelid = Drinks.eModel[PickRandom(Drinks.eModel)],
        position =     Vector3(-2162.421044921875, 639.2874145507813, 1057.5271),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    drink:Create()
    table.insert(self.Objects, drink)

    cigarette = Cigarette {
        modelid = Cigarette.eModel.Cigarette1,
        position =     Vector3(0, 0, 0),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    local livingRoomEntranceLocation = Location(-2170.126708984375, 638.444580078125, 1057.5971, 0, self.InteriorId, "livin room")
    local livingRoomSofaLocation = Location(-2165.447412109375, 643.7353515625, 1057.5971, 0, self.InteriorId, "sofa")
    local livingRoomMusicPlayerLocation = Location(-2166.1552734375, 641.7701416015625, 1057.5971, 180, self.InteriorId, "music player")
    local livingRoomMusicPlayerLocation2 = Location(-2166.1552734375, 642.8620361328125, 1057.5971, 180, self.InteriorId, "music player")
    local livingRoomMusicPlayerLocation3 = Location(-2166.1552734375, 641.7701416015625, 1057.5971, 180, self.InteriorId, "music player")
    
    local kitchenChairLocation = Location(-2160.218017578125, 642.3208129882813, 1057.5971, 0, self.InteriorId, "chair")
    local kitchenTableLocation = Location(-2161.821044921875, 639.2874145507813, 1057.5971, 90, self.InteriorId, "chair")
    
    local livingRoomSmokeLocation1 = Location(-2164.91796875, 646.1671142578125, 1057.5971, 0, self.InteriorId, "smoke")

    local livingRoomEndLocation = Location(-2170.126708984375, 638.444580078125, 1057.5971, 180, self.InteriorId, "livin room")

    table.insert(self.ValidStartingLocations, livingRoomEntranceLocation)

    local pointsOfInterests = {livingRoomSofaLocation, livingRoomMusicPlayerLocation, kitchenChairLocation, kitchenTableLocation, livingRoomSmokeLocation1, livingRoomEndLocation}
    pointsOfInterests = Shuffle(pointsOfInterests)

    if pointsOfInterests[1] == livingRoomEndLocation then
        local i = math.random(#pointsOfInterests - 1) + 1
        pointsOfInterests[1], pointsOfInterests[i] = pointsOfInterests[i], pointsOfInterests[1]
    end

    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = pointsOfInterests[1], targetItem = pointsOfInterests[1], graphId = self.graphId })

    -- sit on sofa
    local sitOnSofaAction = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofaLocation, targetItem = livingroomSofa, rotation = Vector3(0,0,270), graphId = self.graphId}
    table.insert(livingRoomSofaLocation.PossibleActions, sitOnSofaAction)
    local standUpSofaAction = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofaLocation, targetItem = livingroomSofa, graphId = self.graphId}
    sitOnSofaAction.NextAction = standUpSofaAction
    moveToPOS2Action = Move { performer = player, nextLocation = pointsOfInterests[2], targetItem = pointsOfInterests[2], graphId = self.graphId }
    standUpSofaAction.NextAction = moveToPOS2Action
    sitOnSofaAction.ClosingAction = moveToPOS2Action

    -- dance at the music player
    local turnOnMusicPlayerAction = TurnOn { performer = player, nextLocation = livingRoomMusicPlayerLocation, targetItem = musicPlayer, graphId = self.graphId }
    table.insert(livingRoomMusicPlayerLocation.PossibleActions, turnOnMusicPlayerAction)
    local moveToMusicPlayer2Action = Move { performer = player, nextLocation = livingRoomMusicPlayerLocation2, targetItem = livingRoomMusicPlayerLocation2, graphId = self.graphId }
    turnOnMusicPlayerAction.NextAction = moveToMusicPlayer2Action
    local danceMusicPlayerAction = Dance { performer = player, nextLocation = livingRoomMusicPlayerLocation2, targetItem = livingRoomMusicPlayerLocation2, graphId = self.graphId }
    table.insert(livingRoomMusicPlayerLocation2.PossibleActions, danceMusicPlayerAction)
    local moveToMusicPlayer3Action = Move { performer = player, nextLocation = livingRoomMusicPlayerLocation3, targetItem = livingRoomMusicPlayerLocation3, graphId = self.graphId }
    danceMusicPlayerAction.NextAction = moveToMusicPlayer3Action
    local turnOffMusicPlayerAction = TurnOff { performer = player, nextLocation = livingRoomMusicPlayerLocation3, targetItem = musicPlayer, graphId = self.graphId }
    table.insert(livingRoomMusicPlayerLocation3.PossibleActions, turnOffMusicPlayerAction)
    local moveToPOS3Action = Move { performer = player, nextLocation = pointsOfInterests[3], targetItem = pointsOfInterests[3], graphId = self.graphId }
    turnOffMusicPlayerAction.NextAction = moveToPOS3Action
    turnOffMusicPlayerAction.ClosingAction = moveToPOS3Action

    -- sit in the chair
    local sitDownKitchenChairAction = SitDown {how = SitDown.eHow.atDesk, performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChair, rotation = Vector3(0,0,0), graphId = self.graphId}
    table.insert(kitchenChairLocation.PossibleActions, sitDownKitchenChairAction)
    local readKitchenChairAction = Read { performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenBook, graphId = self.graphId }
    sitDownKitchenChairAction.NextAction = readKitchenChairAction
    local standUpKitchenChairAction = StandUp {how = StandUp.eHow.fromDesk, performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChair, graphId = self.graphId}
    readKitchenChairAction.NextAction = standUpKitchenChairAction
    local moveToPOS4Action = Move { performer = player, nextLocation = pointsOfInterests[4], targetItem = pointsOfInterests[4], graphId = self.graphId }
    standUpKitchenChairAction.NextAction = moveToPOS4Action
    sitDownKitchenChairAction.ClosingAction = moveToPOS4Action

    -- drink at table
    local pickUpDrinkAction = PickUp {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, where = "the table", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(kitchenTableLocation.PossibleActions, pickUpDrinkAction)
    local drinkAction = Drink {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, graphId = self.graphId}
    pickUpDrinkAction.NextAction = drinkAction
    local putDownDrinkAction = PutDown {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, where = "the table", targetObjectPosition = Vector3(-2162.421044921875, 639.2874145507813, 1057.5271),
                                        targetObjectRotation = Vector3(0, 0, 0), graphId = self.graphId}
    drinkAction.NextAction = putDownDrinkAction

    local moveToPOS5Action = Move { performer = player, nextLocation = pointsOfInterests[5], targetItem = pointsOfInterests[5], graphId = self.graphId}
    putDownDrinkAction.NextAction = moveToPOS5Action
    pickUpDrinkAction.ClosingAction = moveToPOS5Action

    -- smoke at painting
    local livingroomSmokeInAction = SmokeIn { performer = player, nextLocation = livingRoomSmokeLocation1, targetItem = cigarette, graphId = self.graphId }
    table.insert(livingRoomSmokeLocation1.PossibleActions, livingroomSmokeInAction)
    local livingroomSmokeAction = Smoke { performer = player, nextLocation = livingRoomSmokeLocation1, targetItem = cigarette, graphId = self.graphId }
    livingroomSmokeInAction.NextAction = livingroomSmokeAction
    local livingroomSmokeOutAction = SmokeOut { performer = player, nextLocation = livingRoomSmokeLocation1, targetItem = cigarette, graphId = self.graphId }
    livingroomSmokeAction.NextAction = livingroomSmokeOutAction

    local moveToPOS6Action = Move { performer = player, nextLocation = pointsOfInterests[6], targetItem = pointsOfInterests[6], graphId = self.graphId}
    livingroomSmokeOutAction.NextAction = moveToPOS6Action
    livingroomSmokeInAction.ClosingAction = moveToPOS6Action

    table.insert(livingRoomEndLocation.PossibleActions, EndStory())

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