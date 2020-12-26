House8 = class(StoryEpisodeBase, function(o)
    StoryEpisodeBase.init(o, {name = 'house8'})
    o:LoadFromFile()
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
    table.insert(self.Objects, bedroomChair)

    removeWorldModel(2333, 0.25, Vector3(2367.5703, -1122.1484, 1049.8672))
    local desk = Desk{
        modelid =      Desk.eModel.BedroomDesk,
        position =     Vector3(2367.57031, -1122.14844, 1049.76184),
        rotation =     Vector3(356.85840, 0.00000, -90),
        noCollisions = true,
        interior =     self.InteriorId
    }
    table.insert(self.Objects, desk)
    --Create a closed laptop on the table
    local laptop = Laptop{
        modelid =      Laptop.eModel.Closed,
        position =     Vector3(2368.36450, -1122.66003, 1050.703450),
        rotation =     Vector3(0.00000, 0.00000, -90),
        noCollisions = true,
        interior =     self.InteriorId
    }
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
    table.insert(self.Objects, bedroom1Bed)
    
    local bedroom2Bed = Bed{
        modelid =      Bed.eModel.SwankBed7,
        position =     Vector3(2361.29688,-1134.14844,1049.85938),
        rotation =     Vector3(360,0.00000,90),
        noCollisions = true,
        interior =     self.InteriorId
    }
    removeWorldModel(Bed.eModel.SwankBed7, 0.25, bedroom2Bed.position)    
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
    table.insert(self.Objects, sofaLeft)
    
    --define the points of interest, set them all as valid starting locations and define walk actions between all of them
    local bedroom1 = Location(2363.0017, -1123.7264, 1050.8750, 357.2968, self.InteriorId, " bedroom near the bed ")
    local atDesk = Location(2367.232421875, -1122.6044921875, 1050.875, 266.2842, self.InteriorId, " the desk ")
    local rightSofa = Location(2370.9368, -1124.0031, 1050.8750, 95.8058, self.InteriorId, " right sofa in the living room ")
    local leftSofa = Location(2374.1345, -1124.0991, 1050.8750, 262.7906, self.InteriorId, " left sofa in the living room ")
    local centralSofa = Location(2372.0334, -1122.0536, 1050.8750, 356.7915, self.InteriorId, " central sofa in the living room ")
    local kitchenNearTheSink = Location(2373.8518, -1132.2216, 1050.875, 270.25897, self.InteriorId, " kitchen at the sink ")
    local bedroom2 = Location(2359.0698, -1134.0743, 1050.8750, 357.9942, self.InteriorId, " bedroom near the bed ")
    local hallwayToEntrance = Location(2365.3000, -1132.9200, 1050.8750, 180, self.InteriorId, " hallway to entrance door ")

    self.POI = {
        bedroom1,
        atDesk,
        rightSofa,
        leftSofa,
        centralSofa,
        kitchenNearTheSink,
        bedroom2,
        hallwayToEntrance 
    }
    
    local getInBedAction = GetOn{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1, how = GetOn.eHow.Bed, side = GetOn.eSide.Left, graphId = self.graphId}
    table.insert(bedroom1.PossibleActions, getInBedAction)
    local sleepAction = Sleep{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1}
    getInBedAction.NextAction = sleepAction    
    local getOffBedAction = GetOff{performer = player, targetItem = bedroom1Bed, nextLocation = bedroom1,  how = GetOff.eHow.Bed, side = GetOff.eSide.Left, graphId = self.graphId}
    sleepAction.NextAction = getOffBedAction
    getInBedAction.ClosingAction = getOffBedAction
    
    local sitAtDeskAction = SitDown{how = SitDown.eHow.atDesk, performer = player, nextLocation = atDesk, targetItem = bedroomChair }
    table.insert(atDesk.PossibleActions, sitAtDeskAction)
    local openLaptopAction = OpenLaptop{performer = player, nextLocation = atDesk, targetItem = laptop }
    sitAtDeskAction.NextAction = openLaptopAction

    local writeOnLaptop = TypeOnKeyboard{performer = player, nextLocation = atDesk, targetItem = laptop }
    local punchSeated = PunchSeated{performer = player, nextLocation = atDesk, targetItem = laptop }
    local layOnElbow = LayOnElbow{performer = player, nextLocation = atDesk, targetItem = laptop }
    local lookAtWatch = LookAtTheWatch{performer = player, nextLocation = atDesk, targetItem = laptop }
    local closeLaptopAction = CloseLaptop{performer = player, nextLocation = atDesk, targetItem = laptop }

    local randomActions = {writeOnLaptop, punchSeated, layOnElbow, lookAtWatch, closeLaptopAction}
    openLaptopAction.NextAction = randomActions
    writeOnLaptop.NextAction = randomActions
    punchSeated.NextAction = randomActions
    layOnElbow.NextAction = randomActions
    lookAtWatch.NextAction = randomActions

    local standUpFromDeskAction = StandUp{ how = StandUp.eHow.fromDesk, performer = player, nextLocation = atDesk, targetItem = bedroomChair }
    closeLaptopAction.NextAction = standUpFromDeskAction
    sitAtDeskAction.ClosingAction = standUpFromDeskAction
        
    local sitOnRightSofaAction = SitDown{how = SitDown.eHow.onSofa, performer = player, nextLocation = rightSofa, targetItem = sofaRight }
    table.insert(rightSofa.PossibleActions, sitOnRightSofaAction)
    local standUpFromRightSofaAction = StandUp{ how = StandUp.eHow.fromSofa, performer = player, nextLocation = rightSofa, targetItem = sofaRight }
    sitOnRightSofaAction.ClosingAction = standUpFromRightSofaAction
    sitOnRightSofaAction.NextAction = standUpFromRightSofaAction
    
    local sitOnCentralSofaAction = SitDown{how = SitDown.eHow.onSofa, performer = player, nextLocation = centralSofa, targetItem = sofaCenter }
    table.insert(centralSofa.PossibleActions, sitOnCentralSofaAction)
    local standUpFromCentralSofaAction = StandUp {how = StandUp.eHow.fromSofa, performer = player, nextLocation = centralSofa, targetItem = sofaCenter }
    sitOnCentralSofaAction.ClosingAction = standUpFromCentralSofaAction
    sitOnCentralSofaAction.NextAction = standUpFromCentralSofaAction
    
    local sitOnLeftSofaAction = SitDown{how = SitDown.eHow.onSofa, performer = player, nextLocation = leftSofa, targetItem = sofaLeft }
    table.insert(leftSofa.PossibleActions, sitOnLeftSofaAction)
    local standUpFromLeftSofaAction = StandUp{ how = StandUp.eHow.fromSofa, performer = player, nextLocation = leftSofa, targetItem = sofaLeft }
    sitOnLeftSofaAction.ClosingAction = standUpFromLeftSofaAction
    sitOnLeftSofaAction.NextAction = standUpFromLeftSofaAction
    
    local washHandsAction = WashHands { performer = player, nextLocation = kitchenNearTheSink, targetItem = kitchenNearTheSink }
    table.insert(kitchenNearTheSink.PossibleActions, washHandsAction)
    
    local getInBed2Action = GetOn{performer = player, targetItem = bedroom2Bed, nextLocation = bedroom2, how = GetOn.eHow.Bed, side = GetOn.eSide.Left, graphId = self.graphId}
    table.insert(bedroom2.PossibleActions, getInBed2Action)

    local sleepAction2 = Sleep { nextLocation = bedroom2, performer = player, targetItem = bedroom2Bed }
    getInBed2Action.NextAction = sleepAction2
    local getOffBed2Action = GetOff{performer = player, targetItem = bedroom2Bed, nextLocation = bedroom2,  how = GetOff.eHow.Bed, side = GetOff.eSide.Left, graphId = self.graphId}
    sleepAction2.NextAction = getOffBed2Action
    sleepAction2.ClosingAction = getOffBed2Action

    StoryEpisodeBase.Initialize(self, arg)

    if DEBUG then
        outputConsole("House8:Initialized")
    end

    return true
end

function House8:Destroy()
    for _, item in ipairs(self.Objects) do
        item:Destroy()
    end
    if unloadPathGraph and self.graphId then
        unloadPathGraph(self.graphId)
    end
    if DEBUG then
        outputConsole("House8:Destroyed")
    end
    StoryEpisodeBase.Destroy(self)
end