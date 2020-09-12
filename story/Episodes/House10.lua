House10 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, 'house10', nil, nil, nil)
    o:LoadFromFile()
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
    StoryEpisodeBase.Initialize(self, arg)

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

    livingroomTurnTable = TurnTable {
        modelid = TurnTable.eModel.Unknown01,
        position =     Vector3(2262.8047, -1208.4922, 1048.0156),
        rotation =     Vector3(0, 0.0000, 270),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(TurnTable.eModel.Unknown01, 0.25, livingroomTurnTable.position)    
    livingroomTurnTable:Create()
    table.insert(self.Objects, livingroomTurnTable)

    kitchenSink = Furniture {
        modelid = Furniture.eModel.House10Kitchen1,
        position =     Vector3(2247.5469, -1210.9688, 1048.0156),
        rotation =     Vector3(0, 0.0000, 90),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Furniture.eModel.House10Kitchen1, 0.25, kitchenSink.position)    
    kitchenSink:Create()
    table.insert(self.Objects, kitchenSink)

    kitchenChair = Chair {
        modelid = Chair.eModel.RedChair,
        position =     Vector3(2250.3047, -1211.0984, 1048.5234),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Chair.eModel.RedChair, 0.25, kitchenChair.position)    
    kitchenChair:Create()
    table.insert(self.Objects, kitchenChair)

    kitchenTable = Table {
        modelid = Table.eModel.WoodRoundTable,
        position =     Vector3(2250.2813, -1212.2500, 1048.4141),
        rotation =     Vector3(0, 0.0000, 0),
        noCollisions = true,
        interior = self.InteriorId
    }

    removeWorldModel(Table.eModel.WoodRoundTable, 0.25, kitchenTable.position)    
    kitchenTable:Create()
    table.insert(self.Objects, kitchenTable)

    local food = Food {
        modelid = Food.eModel[PickRandom(Food.eModel)],
        noCollisions = true,
        position =     Vector3(2249.8813, -1211.5500, 1048.9141),
        rotation =     Vector3(0, 0, 0),
        interior = self.InteriorId
    }
    food:Create()
    table.insert(self.Objects, food)

    local plate = Plate {
        modelid = Plate.eModel.Unknown2,
        noCollisions = true,
        position =     Vector3(2249.8813, -1211.6700, 1048.8441),
        rotation =     Vector3(0, 0, 0),
        interior = self.InteriorId
    }
    plate:Create()
    table.insert(self.Objects, plate)

    local bedroomBed = Bed{
        modelid =      Bed.eModel.Unknown9,
        position =     Vector3(2258.5938, -1221.5469, 1048.0156),
        rotation =     Vector3(0, 0, 180),
        noCollisions = true,
        interior =     self.InteriorId
    }
    removeWorldModel(Bed.eModel.Unknown9, 5.25, bedroomBed.position)
    bedroomBed:Create()
    table.insert(self.Objects, bedroomBed)

    local bathroomSink = Sink {
        modelid =      Sink.eModel.bathroomSink01,
        position =     Vector3(2254.1953, -1215.4531, 1048.0156),
        rotation =     Vector3(0, 0, 0),
        noCollisions = true,
        interior =     self.InteriorId
    }
    removeWorldModel(Sink.eModel.bathroomSink01, 5.25, bathroomSink.position)
    bathroomSink:Create()
    table.insert(self.Objects, bathroomSink)

    phone = MobilePhone {
        modelid = MobilePhone.eModel[PickRandom(MobilePhone.eModel)],
        position = Vector3(0,0,0),
        rotation = Vector3(0,0,0),
        noCollisions = true,
        interior = self.InteriorId
    }

    local livingRoomEntranceLocation = Location(2268.8281, -1210.2188, 1047.5547, 90, self.InteriorId, "hallway")
    local livingRoomSofa1Location = Location(2260.131591796875, -1212.724375, 1049.0234375, 45, self.InteriorId, "living room")
    local livingRoomSofa2Location = Location(2258.73193359375, -1208.188510742188, 1049.0234375, 180, self.InteriorId, "living room")
    local livingRoomTurnTableLocation = Location(2261.96025390625, -1208.617553710938, 1049.0234375, 270, self.InteriorId, "living room turn table")
    local livingRoomTurnTableLocation2 = Location(2260.27001953125, -1208.896508789063, 1049.0234375, 270, self.InteriorId, "living room")
    local livingRoomAnswerPhoneLocation = Location(2256.88818359375, -1211.824951171875, 1049.0234375, 90, self.InteriorId, "living room")

    local kitchenSinkLocation = Location(2247.92060546875, -1209.934448242188, 1049.0234375, 90, self.InteriorId, "kitchen")
    local kitchenChairLocation = Location(2250.29248046875, -1210.4216796875, 1049.0234375, 180, self.InteriorId, "kitchen")

    local bedroomEntranceLocation = Location(2261.1142578125, -1218.331787109375, 1049.0234375, 180, self.InteriorId, "bedroom")
    local bedroomExitLocation = Location(2261.194580078125, -1220.606567382813, 1049.0234375, 180, self.InteriorId, "bedroom")
    local bedroomBedLocation = Location(2259.509521484375, -1223.532592773438, 1049.0234375, 90, self.InteriorId, "bedroom")

    local bathroomEntranceLocation = Location(2257.67041015625, -1216.752075195313, 1049.0234375, 90, self.InteriorId, "bathroom")
    local bathroomExitLocation = Location(2256.31640625, -1216.80224609375, 1049.0234375, 270, self.InteriorId, "bathroom")
    local bathroomSinkLocation = Location(2254.75048828125, -1215.560229492188, 1049.0234375, 0, self.InteriorId, "bathroom")

    local livingRoomEndLocation = Location(2268.8281, -1210.2188, 1047.5547, 270, self.InteriorId, "house exit hallway")
    
    table.insert(self.ValidStartingLocations, livingRoomEntranceLocation)

    self.POI = {livingRoomSofa1Location, livingRoomSofa2Location, livingRoomTurnTableLocation, livingRoomAnswerPhoneLocation, kitchenSinkLocation, 
                bedroomEntranceLocation, bathroomEntranceLocation, livingRoomEndLocation}

    if self.POI[1] == livingRoomEndLocation then
        local i = math.random(6) + 1
        self.POI[1], self.POI[i] = self.POI[i], self.POI[1]
    end

    table.insert(livingRoomEntranceLocation.PossibleActions, Move { performer = player, nextLocation = self.POI[1], targetItem = self.POI[1], graphId = self.graphId })
    
    -- sit on sofa1
    local sitOnSofa1Action = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofa1Location, targetItem = livingroomSofa1, rotation = Vector3(0,0,225), graphId = self.graphId}
    table.insert(livingRoomSofa1Location.PossibleActions, sitOnSofa1Action)
    local standUpSofa1Action = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofa1Location, targetItem = livingroomSofa1, graphId = self.graphId}
    sitOnSofa1Action.NextAction = standUpSofa1Action
    local  moveToPOI3Action = Move { performer = player, nextLocation = self.POI[2], targetItem = self.POI[2], graphId = self.graphId }
    standUpSofa1Action.NextAction = moveToPOI3Action
    sitOnSofa1Action.ClosingAction = moveToPOI3Action

    -- sit on sofa2
    local sitOnSofa2Action = SitDown {how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomSofa2Location, targetItem = livingroomSofa2, rotation = Vector3(0,0,0), graphId = self.graphId}
    table.insert(livingRoomSofa2Location.PossibleActions, sitOnSofa2Action)
    local standUpSofa2Action = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = livingRoomSofa2Location, targetItem = livingroomSofa2, graphId = self.graphId}
    sitOnSofa2Action.NextAction = standUpSofa2Action
    moveToPOI3Action = Move { performer = player, nextLocation = self.POI[3], targetItem = self.POI[3], graphId = self.graphId }
    standUpSofa2Action.NextAction = moveToPOI3Action
    sitOnSofa2Action.ClosingAction = moveToPOI3Action

    -- dance next to the turntable
    local turnOnTurnTableAction = TurnOn { performer = player, nextLocation = livingRoomTurnTableLocation, targetItem = livingroomTurnTable, graphId = self.graphId }
    table.insert(livingRoomTurnTableLocation.PossibleActions, turnOnTurnTableAction)
    local moveToTurnTable2Action = Move { performer = player, nextLocation = livingRoomTurnTableLocation2, targetItem = livingRoomTurnTableLocation2, graphId = self.graphId }
    turnOnTurnTableAction.NextAction = moveToTurnTable2Action
    local danceTurnTableAction = Dance { performer = player, nextLocation = livingRoomTurnTableLocation2, targetItem = livingRoomTurnTableLocation2, graphId = self.graphId }
    table.insert(livingRoomTurnTableLocation2.PossibleActions, danceTurnTableAction)
    local moveToTurnTable3Action = Move { performer = player, nextLocation = livingRoomTurnTableLocation, targetItem = livingRoomTurnTableLocation, graphId = self.graphId }
    danceTurnTableAction.NextAction = moveToTurnTable3Action
    local turnOffTurnTableAction = TurnOff { performer = player, nextLocation = livingRoomTurnTableLocation, targetItem = livingroomTurnTable, graphId = self.graphId }
    moveToTurnTable3Action.NextAction = turnOffTurnTableAction
    local moveToPOI4Action = Move { performer = player, nextLocation = self.POI[4], targetItem = self.POI[4], graphId = self.graphId }
    turnOffTurnTableAction.NextAction = moveToPOI4Action
    turnOffTurnTableAction.ClosingAction = moveToPOI4Action

    -- answer phone
    local answerPhoneAction = AnswerPhone { performer = player, nextLocation = livingRoomAnswerPhoneLocation, targetItem = phone, graphId = self.graphId }
    table.insert(livingRoomAnswerPhoneLocation.PossibleActions, answerPhoneAction)
    local talkPhoneAction = TalkPhone { performer = player, nextLocation = livingRoomAnswerPhoneLocation, targetItem = phone, graphId = self.graphId }
    answerPhoneAction.NextAction = talkPhoneAction
    local hangUpAction = HangUp { performer = player, nextLocation = livingRoomAnswerPhoneLocation, targetItem = phone, graphId = self.graphId }
    talkPhoneAction.NextAction = hangUpAction
    local moveToPOI5Action = Move { performer = player, nextLocation = self.POI[5], targetItem = self.POI[5], graphId = self.graphId }
    hangUpAction.NextAction = moveToPOI5Action
    answerPhoneAction.ClosingAction = moveToPOI5Action

    -- kitchen actions
    local washHandsKitchenAction = WashHands {performer = player, nextLocation = kitchenSinkLocation, targetItem = kitchenSink, graphId = self.graphId}
    table.insert(kitchenSinkLocation.PossibleActions, washHandsKitchenAction)
    local  moveToKitchenChairAction = Move { performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChairLocation, graphId = self.graphId }
    washHandsKitchenAction.NextAction = moveToKitchenChairAction

    local sitDownKitchenChairAction = SitDown {how = SitDown.eHow.atDesk, performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChair, rotation = Vector3(0,0,180), graphId = self.graphId}
    table.insert(kitchenChairLocation.PossibleActions, sitDownKitchenChairAction)
    local pickUpFoodAction = PickUp {performer = player, nextLocation = kitchenChairLocation, targetItem = food, where = "the table", targetObjectExists = true, how = PickUp.eHow.Sit, graphId = self.graphId}
    sitDownKitchenChairAction.NextAction = pickUpFoodAction
    local eatFoodAction = Eat {performer = player, nextLocation = kitchenChairLocation, targetItem = food, graphId = self.graphId, how = Eat.eHow.SitDown}
    pickUpFoodAction.NextAction = eatFoodAction
    local standUpKitchenChairAction = StandUp {how = StandUp.eHow.fromDesk, performer = player, nextLocation = kitchenChairLocation, targetItem = kitchenChair, graphId = self.graphId}
    eatFoodAction.NextAction = standUpKitchenChairAction
    local moveToPOI6Action = Move { performer = player, nextLocation = self.POI[6], targetItem = self.POI[6], graphId = self.graphId }
    standUpKitchenChairAction.NextAction = moveToPOI6Action
    sitDownKitchenChairAction.ClosingAction = moveToPOI6Action

    -- bedroom actions
    local openBedroomDoorAction = OpenDoor {performer = player, nextLocation = bedroomExitLocation, targetItem = bedroomExitLocation, how = OpenDoor.eHow.Enter, graphId = self.graphId}
    table.insert(bedroomEntranceLocation.PossibleActions, openBedroomDoorAction)

    local moveToBedroomBedAction = Move { performer = player, nextLocation = bedroomBedLocation, targetItem = bedroomBedLocation, graphId = self.graphId }
    table.insert(bedroomExitLocation.PossibleActions, moveToBedroomBedAction)

    local getInBedAction = GetOn {performer = player, targetItem = bedroomBed, nextLocation = bedroomBedLocation, how = GetOn.eHow.Bed, side = GetOn.eSide.Left, graphId = self.graphId}
    table.insert(bedroomBedLocation.PossibleActions, getInBedAction)
    local sleepAction = Sleep { nextLocation = bedroomBedLocation, performer = player, targetItem = bedroomBed, how = Sleep.eHow.Left, graphId = self.graphId}
    getInBedAction.NextAction = sleepAction
    local getOffBedAction = GetOff {performer = player, targetItem = bedroomBed, nextLocation = bedroomBedLocation, how = GetOff.eHow.Bed, graphId = self.graphId}
    sleepAction.NextAction = getOffBedAction
    local moveToBedroomExitAction = Move { performer = player, nextLocation = bedroomExitLocation, targetItem = bedroomExitLocation, graphId = self.graphId}
    getOffBedAction.NextAction = moveToBedroomExitAction

    local openBedroomDoorAction2 = OpenDoor {performer = player, nextLocation = bedroomEntranceLocation, targetItem = bedroomEntranceLocation, how = OpenDoor.eHow.Exit, graphId = self.graphId}
    moveToBedroomExitAction.NextAction = openBedroomDoorAction2
    
    local moveToPOI7Action = Move { performer = player, nextLocation = self.POI[7], targetItem = self.POI[7], graphId = self.graphId}
    openBedroomDoorAction2.NextAction = moveToPOI7Action
    openBedroomDoorAction.ClosingAction = moveToPOI7Action

    -- bathroom actions
    local openbathRoomAction = OpenDoor {performer = player, nextLocation = bathroomSinkLocation, targetItem = bathroomSink, how = OpenDoor.eHow.Enter, graphId = self.graphId}
    table.insert(bathroomEntranceLocation.PossibleActions, openbathRoomAction)

    local washhandsBathroomSinkAction = WashHands {performer = player, nextLocation = bathroomSinkLocation, targetItem = bathroomSink, graphId = self.graphId}
    table.insert(bathroomSinkLocation.PossibleActions, washhandsBathroomSinkAction)
    local moveToBathroomExitAction = Move { performer = player, nextLocation = bathroomExitLocation, targetItem = bathroomExitLocation, graphId = self.graphId}
    washhandsBathroomSinkAction.NextAction = moveToBathroomExitAction

    local openbathRoomAction2 = OpenDoor {performer = player, nextLocation = bathroomEntranceLocation, targetItem = bathroomEntranceLocation, how = OpenDoor.eHow.Exit, graphId = self.graphId}
    table.insert(bathroomExitLocation.PossibleActions, openbathRoomAction2)

    local moveToPOI8Action = Move { performer = player, nextLocation = self.POI[8], targetItem = self.POI[8], graphId = self.graphId}
    openbathRoomAction2.NextAction = moveToPOI8Action
    openbathRoomAction.ClosingAction = moveToPOI8Action

    table.insert(livingRoomEndLocation.PossibleActions, EndStory())

    if DEBUG then
        outputConsole("House10:Initialized")
    end
    return true
end

function House10:Play(...)
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
        outputConsole("House10:Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
end
    
function House10:Destroy()
    for _, item in ipairs(self.Objects) do
        item:Destroy()
    end
    if unloadPathGraph and self.graphId then
        unloadPathGraph(self.graphId)
    end
    if DEBUG then
        outputConsole("House10:Destroyed")
    end
    StoryEpisodeBase.Destroy(self)
end
