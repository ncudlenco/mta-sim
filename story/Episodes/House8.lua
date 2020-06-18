House8 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, nil, nil, nil)
    o.InteriorId = 8
    if not loadPathGraph then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return
    end

    -- Load path graph
    o.graphId = loadPathGraph("files/paths/house8.json")
    if not findShortestPathBetween then
        outputDebugString("Pathfinding module not loaded. Exiting...", 2)
        return false
    end
end)

function House8:Initialize(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end
    
    --Remove the porn painting from the bedroom wall
    removeWorldModel(2255, 0.25, Vector3(2361.5703, -1122.1484, 1052.2109))
    --Add a painting (San Fierro bridge) on the bedroom wall
    local painting = Object(2281, Vector3(2361.59473, -1122.49927, 1051.87500), Vector3(360.00000, 0.00000, 90.00000))
    painting:setInterior(self.InteriorId)
    --Remove the chair from the buro in bedroom 1
    removeWorldModel(2331, 0.25, Vector3(2367.3672, -1123.1563, 1050.1172))
    local bedroomChair = Chair{
        modelid =      Chair.eModel.BedroomChair,
        position =     Vector3(2367.77393, -1122.64612, 1049.91719),
        rotation =     Vector3(356.85840, 0.00000, 359.39059),
        noCollisions = true,
        interior =     self.InteriorId
    }
    bedroomChair:Create()
    table.insert(self.Objects, bedroomChair)

    removeWorldModel(2333, 0.25, Vector3(2367.5703, -1122.1484, 1049.8672))
    local desk = Desk{
        modelid =      Desk.eModel.BedroomDesk,
        position =     Vector3(2367.57031, -1122.14844, 1049.76184),
        rotation =     Vector3(356.85840, 0.00000, -90),
        noCollisions = true,
        interior =     self.InteriorId
    }
    desk:Create()
    table.insert(self.Objects, desk)
--TODO: update player starting position to sit down at the desk
--TODO: update the laptop height
    --Create a closed laptop on the table
    local laptop = Laptop{
        modelid =      Laptop.eModel.Closed,
        position =     Vector3(2368.36450, -1122.66003, 1050.703450),
        rotation =     Vector3(0.00000, 0.00000, -90),
        noCollisions = true,
        interior =     self.InteriorId
    }
    laptop:Create()
    table.insert(self.Objects, laptop)

    local photos = Photos 
    {
        modelid = 2828, 
        position = Vector3(2374.25781, -1129.25781, 1050.78906), 
        rotation = Vector3(356.85840, 0.00000, 360),
        noCollisions = true,
        interior = self.InteriorId
    };

    local bedroom1Bed = Bed{
        modelid =      Bed.eModel.LowBed,
        position =     Vector3(2364.55469, -1122.96875, 1049.86719),
        rotation =     Vector3(360, 0.00000, 90),
        noCollisions = true,
        interior =     self.InteriorId
    }
    removeWorldModel(Bed.eModel.LowBed, 0.25, bedroom1Bed.position)    
    bedroom1Bed:Create()
    table.insert(self.Objects, bedroom1Bed)
    
    local bedroom2Bed = Bed{
        modelid =      Bed.eModel.SwankBed7,
        position =     Vector3(2361.29688,-1134.14844,1049.85938),
        rotation =     Vector3(360,0.00000,90),
        noCollisions = true,
        interior =     self.InteriorId
    }
    removeWorldModel(Bed.eModel.SwankBed7, 0.25, bedroom2Bed.position)    
    bedroom2Bed:Create()
    table.insert(self.Objects, bedroom2Bed)

    local sofaRight = Sofa
    {
        modelid = Sofa.eModel.Couch02,
        position = Vector3(2370.39063, -1124.43750, 1049.84375),
        rotation = Vector3(360, 0.00000, 90),
        noCollisions = true,
        interior = self.InteriorId
    }
    removeWorldModel(Sofa.eModel.Couch02, 0.25, sofaRight.position)    
    sofaRight:Create()
    table.insert(self.Objects, sofaRight)

    local sofaCenter = Sofa
    {
        modelid = Sofa.eModel.Couch02,
        position = Vector3(2371.60156, -1121.50781, 1049.84375),
        rotation = Vector3(360, 0.00000, 360),
        noCollisions = true,
        interior = self.InteriorId
    }
    removeWorldModel(Sofa.eModel.Couch02, 0.25, sofaCenter.position)    
    sofaCenter:Create()
    table.insert(self.Objects, sofaCenter)

    local sofaLeft = Sofa
    {
        modelid = Sofa.eModel.Couch02,
        position = Vector3(2374.67969, -1122.53125, 1049.84375),
        rotation = Vector3(360, 0.00000, -90),
        noCollisions = true,
        interior = self.InteriorId
    }
    removeWorldModel(Sofa.eModel.Couch02, 0.25, sofaLeft.position)    
    sofaLeft:Create()
    table.insert(self.Objects, sofaLeft)

    local bedroom1FacingBedLeft = Location(2363.0017, -1123.7264, 1050.8750, 357.2968, self.InteriorId, " bedroom near the bed ")
    local bedroom1BackToBedLeft = Location(2363.0017, -1123.7264, 1050.8750, 177.2968, self.InteriorId, " bedroom near the bed ")
    table.insert(self.ValidStartingLocations, bedroom1FacingBedLeft)
    
    local bedroom1InBedLeft = Location(2362.477, -1123.7567, 1050.875, 357.29678, self.InteriorId, " bedroom on the bed ")
    local getInBedAction = GetInBed{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1InBedLeft}
    table.insert(bedroom1FacingBedLeft.PossibleActions, getInBedAction)
    
    local sleepAction = Sleep{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1InBedLeft, prerequisites = { getInBedAction }}
    table.insert(bedroom1InBedLeft.PossibleActions, sleepAction)
    
    local getOffBedAction = GetOffBed{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1BackToBedLeft, prerequisites = { getInBedAction, sleepAction }}
    table.insert(bedroom1InBedLeft.PossibleActions, getOffBedAction)
    getInBedAction.ClosingAction = getOffBedAction
    sleepAction.ClosingAction = getOffBedAction
    
    local bedroom1AtDeskBefore = Location(2367.232421875, -1122.6044921875, 1050.875, 266.2842, self.InteriorId, " the desk ")
    local bedroom1AtDeskDuring = Location(2367.232421875, -1122.6044921875, 1050.875, 266.2842, self.InteriorId, " the desk ")
    local bedroom1AtDeskAfter = Location(2367.232421875, -1122.6044921875, 1050.875, 86.2842, self.InteriorId, " the desk ")

    table.insert(bedroom1BackToBedLeft.PossibleActions, Move{performer = player, targetItem = bedroom1AtDeskBefore, nextLocation = bedroom1AtDeskBefore, graphId = self.graphId})
    local sitAtDeskAction = SitDown{how = SitDown.eHow.atDesk, performer = player, nextLocation = bedroom1AtDeskDuring, targetItem = bedroomChair }
    table.insert(bedroom1AtDeskBefore.PossibleActions, sitAtDeskAction)
    local openLaptopAction = OpenLaptop{performer = player, nextLocation = bedroom1AtDeskDuring, targetItem = laptop }
    sitAtDeskAction.NextAction = openLaptopAction
    local writeOnLaptop = TypeOnKeyboard{performer = player, nextLocation = bedroom1AtDeskDuring, targetItem = laptop }
    openLaptopAction.NextAction = writeOnLaptop
    local punchSeated = PunchSeated{performer = player, nextLocation = bedroom1AtDeskDuring, targetItem = laptop }
    writeOnLaptop.NextAction = punchSeated
    local layOnElbow = LayOnElbow{performer = player, nextLocation = bedroom1AtDeskDuring, targetItem = laptop }
    punchSeated.NextAction = layOnElbow
    local lookAtWatch = LookAtTheWatch{performer = player, nextLocation = bedroom1AtDeskDuring, targetItem = laptop }
    layOnElbow.NextAction = lookAtWatch
    local closeLaptopAction = CloseLaptop{performer = player, nextLocation = bedroom1AtDeskDuring, targetItem = laptop }
    lookAtWatch.NextAction = closeLaptopAction
    local standUpFromDeskAction = StandUp{ how = StandUp.eHow.fromDesk, performer = player, prerequisites = { sitAtDeskAction }, nextLocation = bedroom1AtDeskAfter, targetItem = bedroomChair }
    sitAtDeskAction.ClosingAction = standUpFromDeskAction
    table.insert(bedroom1AtDeskDuring.PossibleActions, standUpFromDeskAction)
    
    local livingRoomBackToRightSofa = Location(2370.9368, -1124.0031, 1050.8750, 95.8058, self.InteriorId, " right sofa in the living room ")
    local livingRoomBackToRightSofa2 = Location(2370.9368, -1124.0031, 1050.8750, 95.8058, self.InteriorId, " right sofa in the living room ")
    local livingRoomOnTheRightSofa = Location(2370.9368, -1124.0031, 1050.8750, 95.8058, self.InteriorId, " right sofa in the living room ")
    table.insert(bedroom1AtDeskAfter.PossibleActions, Move { performer = player, nextLocation = livingRoomBackToRightSofa, targetItem = livingRoomBackToRightSofa, graphId = self.graphId })
    
    local sitOnRightSofaAction = SitDown{how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomOnTheRightSofa, targetItem = sofaRight }
    table.insert(livingRoomBackToRightSofa.PossibleActions, sitOnRightSofaAction)
    local standUpFromRightSofaAction = StandUp{ how = StandUp.eHow.fromSofa, performer = player, prerequisites = { sitOnRightSofaAction }, nextLocation = livingRoomBackToRightSofa2, targetItem = sofaRight }
    sitOnRightSofaAction.ClosingAction = standUpFromRightSofaAction
    table.insert(livingRoomOnTheRightSofa.PossibleActions, standUpFromRightSofaAction)

    local livingRoomBackToCentralSofa = Location(2372.0334, -1122.0536, 1050.8750, 356.7915, self.InteriorId, " central sofa in the living room ")
    local livingRoomBackToCentralSofa2 = Location(2372.0334, -1122.0536, 1050.8750, 356.7915, self.InteriorId, " central sofa in the living room ")
    local livingRoomOnCentralSofa = Location(2372.0334, -1122.0536, 1050.8750, 356.7915, self.InteriorId, " central sofa in the living room ")
    table.insert(livingRoomBackToRightSofa2.PossibleActions, Move { performer = player, nextLocation = livingRoomBackToCentralSofa, targetItem = livingRoomBackToCentralSofa, graphId = self.graphId })

    local sitOnCentralSofaAction = SitDown{how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomOnCentralSofa, targetItem = sofaCenter }
    table.insert(livingRoomBackToCentralSofa.PossibleActions, sitOnCentralSofaAction)
    local standUpFromCentralSofaAction = StandUp {how = StandUp.eHow.fromSofa, performer = player, prerequisites = { sitOnCentralSofaAction }, nextLocation = livingRoomBackToCentralSofa2, targetItem = sofaCenter }
    sitOnCentralSofaAction.ClosingAction = standUpFromCentralSofaAction
    table.insert(livingRoomOnCentralSofa.PossibleActions, standUpFromCentralSofaAction)

    local livingRoomBackToLeftSofa = Location(2374.1345, -1124.0991, 1050.8750, 262.7906, self.InteriorId, " central sofa in the living room ")
    local livingRoomBackToLeftSofa2 = Location(2374.1345, -1124.0991, 1050.8750, 262.7906, self.InteriorId, " central sofa in the living room ")
    local livingRoomOnLeftSofa = Location(2374.1345, -1124.0991, 1050.8750, 262.7906, self.InteriorId, " central sofa in the living room ")
    table.insert(livingRoomBackToCentralSofa2.PossibleActions, Move { performer = player, nextLocation = livingRoomBackToLeftSofa, targetItem = livingRoomBackToLeftSofa, graphId = self.graphId })

    local sitOnLeftSofaAction = SitDown{how = SitDown.eHow.onSofa, performer = player, nextLocation = livingRoomOnLeftSofa, targetItem = sofaLeft }
    table.insert(livingRoomBackToLeftSofa.PossibleActions, sitOnLeftSofaAction)
    local standUpFromLeftSofaAction = StandUp{ how = StandUp.eHow.fromSofa, performer = player, prerequisites = { sitOnLeftSofaAction }, nextLocation = livingRoomBackToLeftSofa2, targetItem = sofaLeft }
    sitOnLeftSofaAction.ClosingAction = standUpFromLeftSofaAction
    table.insert(livingRoomOnLeftSofa.PossibleActions, standUpFromLeftSofaAction)

    local livingRoomNearPhotos = Location(2373.7715, -1128.37, 1050.8826, 213.83502, self.InteriorId, " living room near the dresser ")
    table.insert(livingRoomBackToLeftSofa2.PossibleActions, Move { performer = player, nextLocation = livingRoomNearPhotos, targetItem = livingRoomNearPhotos, graphId = self.graphId })

    local lookAtPhotosAction = LookAtObject { performer = player, nextLocation = livingRoomNearPhotos, targetItem = photos }
    table.insert(livingRoomNearPhotos.PossibleActions, lookAtPhotosAction)
    
    local kitchenNearTheSink = Location(2373.8518, -1132.2216, 1050.875, 270.25897, self.InteriorId, " kitchen at the sink ")
    table.insert(livingRoomNearPhotos.PossibleActions, Move { performer = player, prerequisites = { lookAtPhotosAction }, nextLocation = kitchenNearTheSink, targetItem = kitchenNearTheSink, graphId = self.graphId })
    local washHandsAction = WashHands { performer = player, nextLocation = kitchenNearTheSink, targetItem = kitchenNearTheSink }
    table.insert(kitchenNearTheSink.PossibleActions, washHandsAction)
    
    local bedroom2BackToBedLeft = Location(2359.0698, -1134.0743, 1050.8750, 177.9942, self.InteriorId, " bedroom near the bed ")
    local bedroom2FacingBedLeft = Location(2359.0698, -1134.0743, 1050.8750, 357.9942, self.InteriorId, " bedroom near the bed ")
    table.insert(kitchenNearTheSink.PossibleActions, Move { performer = player, prerequisites = { washHandsAction }, nextLocation = bedroom2FacingBedLeft, targetItem = bedroom2FacingBedLeft, graphId = self.graphId })

    local bedroom2InBedLeft = Location(2359.0698, -1134.0743, 1050.8750, 357.9942, self.InteriorId, " bedroom near the bed ")
    local getInBed2Action = GetInBed { nextLocation = bedroom2InBedLeft, performer = player, targetItem = bedroom2Bed }
    table.insert(bedroom2FacingBedLeft.PossibleActions, getInBed2Action)

    local sleepAction2 = Sleep { nextLocation = bedroom2InBedLeft, prerequisites = { getInBed2Action }, performer = player, targetItem = bedroom2Bed }
    table.insert(bedroom2InBedLeft.PossibleActions, sleepAction2)
    local getOffBed2Action = GetOffBed { nextLocation = bedroom2BackToBedLeft, prerequisites = { getInBed2Action, sleepAction2 }, performer = player, targetItem = bedroom2Bed }
    table.insert(bedroom2InBedLeft.PossibleActions, getOffBed2Action)
    getInBed2Action.ClosingAction = getOffBed2Action
    sleepAction2.ClosingAction = getOffBed2Action

    
    local hallwayToEntrance = Location(2365.3000, -1132.9200, 1050.8750, 180, self.InteriorId, " hallway to entrance door ")
    table.insert(bedroom2BackToBedLeft.PossibleActions, Move { performer = player, nextLocation = hallwayToEntrance, targetItem = hallwayToEntrance, graphId = self.graphId })

    if DEBUG then
        outputConsole("House8:Initialized")
    end
    return true
end

function House8:Play(...)
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
        outputConsole("House8:Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
end

function House8:Destroy()
    for item in self.Objects do
        item:Destroy()
    end
    unloadPathGraph()
    if DEBUG then
        outputConsole("House8:Destroyed")
    end
end