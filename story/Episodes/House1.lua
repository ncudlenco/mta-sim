House1 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, {name = 'house1'})
    o:LoadFromFile()
    o.InteriorId = 1
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
    table.insert(self.Objects, livingroomSofa)

    local musicPlayer = MusicPlayer {
        modelid = MusicPlayer.eModel.Unknown01,
        position =     Vector3(-2166.2344, 640.9297, 1056.6781),
        rotation =     Vector3(0, 0.0000, 180),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(MusicPlayer.eModel.Unknown01, 0.25, musicPlayer.position)    
    table.insert(self.Objects, musicPlayer)

    local kitchenChair = Furniture {
        modelid = Furniture.eModel.House1LivingRoom2,
        position =     Vector3(-2160.2031, 640.8516, 1058.6016),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House1LivingRoom2, 0.25, kitchenChair.position)    
    table.insert(self.Objects, kitchenChair)

    local kitchenBook = Book {
        modelid = Book.eModel.Book1,
        position =     Vector3(-2160.3831, 643.5516, 1057.3916),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }
   
    table.insert(self.Objects, kitchenBook)
    
    local drink = Drinks {
        modelid = Drinks.eModel[PickRandom(Drinks.eModel)],
        position =     Vector3(-2162.421044921875, 639.2874145507813, 1057.5271),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    table.insert(self.Objects, drink)

    local cigarette = Cigarette {
        modelid = Cigarette.eModel.Cigarette1,
        position =     Vector3(0, 0, 0),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }
    table.insert(self.Objects, cigarette)

    local livingRoomEntranceLocation = Location(-2170.126708984375, 638.444580078125, 1057.5971, 0, self.InteriorId, "living room")
    local livingRoomSofaLocation = Location(-2165.447412109375, 643.7353515625, 1057.5971, 0, self.InteriorId, "living room sofa")
    local livingRoomMusicPlayerLocation = Location(-2166.1552734375, 641.7701416015625, 1057.5971, 180, self.InteriorId, "living room music player")
    local livingRoomMusicPlayerLocation2 = Location(-2166.1552734375, 642.8620361328125, 1057.5971, 180, self.InteriorId, "living room")
    local livingRoomSmokeLocation = Location(-2164.91796875, 646.1671142578125, 1057.5971, 0, self.InteriorId, "living room")
    
    local kitchenChairLocation = Location(-2160.218017578125, 642.3208129882813, 1057.5971, 0, self.InteriorId, "kitchen table")
    local kitchenTableLocation = Location(-2161.821044921875, 639.2874145507813, 1057.5971, 90, self.InteriorId, "kitchen counter")

    
    self.POI = {livingRoomSofaLocation, livingRoomMusicPlayerLocation, kitchenChairLocation, kitchenTableLocation, livingRoomSmokeLocation}

    -- sit on sofa
    local sitOnSofaAction = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofaLocation, targetItem = livingroomSofa, rotation = Vector3(0,0,270), graphId = self.graphId}
    table.insert(livingRoomSofaLocation.PossibleActions, sitOnSofaAction)
    local standUpSofaAction = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofaLocation, targetItem = livingroomSofa, graphId = self.graphId}
    sitOnSofaAction.NextAction = standUpSofaAction
    sitOnSofaAction.ClosingAction = standUpSofaAction

    livingRoomSofaLocation.allActions = {sitOnSofaAction, standUpSofaAction}
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
    turnOffTurnTableAction.ClosingAction = turnOffTurnTableAction

    livingRoomMusicPlayerLocation = {turnOnTurnTableAction, moveToTurnTable2Action, danceTurnTableAction, moveToTurnTable3Action, turnOffTurnTableAction}

    -- sit in the chair
    local sitDownKitchenChairAction = SitDown {how = SitDown.eHow.atDesk, performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChair, rotation = Vector3(0,0,0), graphId = self.graphId}
    table.insert(kitchenChairLocation.PossibleActions, sitDownKitchenChairAction)
    local readKitchenChairAction = Read { performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenBook, graphId = self.graphId }
    sitDownKitchenChairAction.NextAction = readKitchenChairAction
    local standUpKitchenChairAction = StandUp {how = StandUp.eHow.fromDesk, performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChair, graphId = self.graphId}
    readKitchenChairAction.NextAction = standUpKitchenChairAction
    sitDownKitchenChairAction.ClosingAction = standUpKitchenChairAction

    kitchenChairLocation = {sitDownKitchenChairAction, readKitchenChairAction, standUpKitchenChairAction}

    -- drink at table
    local pickUpDrinkAction = PickUp {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, where = "the kitchen counter", targetObjectExists = true, how = PickUp.eHow.Normal, hand = PickUp.eHand.Left, graphId = self.graphId}
    table.insert(kitchenTableLocation.PossibleActions, pickUpDrinkAction)
    local drinkAction = Drink {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, graphId = self.graphId}
    pickUpDrinkAction.NextAction = drinkAction
    local putDownDrinkAction = PutDown {performer = player, nextLocation = kitchenTableLocation, targetItem = drink, where = "the kitchen counter", targetObjectPosition = Vector3(-2162.421044921875, 639.2874145507813, 1057.5271),
                                        targetObjectRotation = Vector3(0, 0, 0), graphId = self.graphId}
    drinkAction.NextAction = putDownDrinkAction
    pickUpDrinkAction.ClosingAction = putDownDrinkAction

    kitchenTableLocation.allActions = {pickUpDrinkAction, drinkAction, putDownDrinkAction}

    -- smoke at painting
    local livingroomSmokeInAction = SmokeIn { performer = player, nextLocation = livingRoomSmokeLocation, targetItem = cigarette, graphId = self.graphId }
    table.insert(livingRoomSmokeLocation.PossibleActions, livingroomSmokeInAction)
    local livingroomSmokeAction = Smoke { performer = player, nextLocation = livingRoomSmokeLocation, targetItem = cigarette, graphId = self.graphId }
    livingroomSmokeInAction.NextAction = livingroomSmokeAction
    local livingroomSmokeOutAction = SmokeOut { performer = player, nextLocation = livingRoomSmokeLocation, targetItem = cigarette, graphId = self.graphId }
    livingroomSmokeAction.NextAction = livingroomSmokeOutAction
    livingroomSmokeInAction.ClosingAction = livingroomSmokeOutAction

    livingRoomSmokeLocation.allActions = {livingroomSmokeInAction, livingroomSmokeAction, livingroomSmokeOutAction}

    StoryEpisodeBase.Initialize(self, unpack(arg))

    if DEBUG then
        outputConsole("House1:Initialized")
    end
    return true
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