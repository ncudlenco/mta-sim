GetOff = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " gets off the ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = params.how
    o.side = params.side or GetOff.eSide.Left
end)


function GetOff:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    -- self.TargetItem.instance:setCollisionsEnabled(false)

    local block = ""
    local animation = ""
    
    if self.how == GetOff.eHow.Bed then
        time = 2800
        block = "INT_HOUSE"

        if self.side == GetOff.eSide.Left then
            animation = "BED_Out_L"
        elseif self.side == GetOff.eSide.Right then
            animation = "BED_Out_R"
        end

    elseif self.how == GetOff.eHow.GymBike then
        time = 1600
        block = "GYMNASIUM"
        animation = "gym_bike_getoff"
    elseif self.how == GetOff.eHow.Treadmill then
        time = 3200
        block = "GYMNASIUM"
        animation = "gym_tread_getoff"
    elseif self.how == GetOff.eHow.Benchpress then
        time = 4000
        block = "GYMNASIUM"
        animation = "gym_bp_getoff"
    end

    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation(block, animation, time, true, true, false, true)
    
    if DEBUG then
        outputConsole("GetOff:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function GetOff:GetDynamicString()
    return 'return GetOff{how = '..self.how..','..'side = '..self.side..'}'
end

GetOff.eHow = {
    Bed = 1,
    GymBike = 2,
    Treadmill = 3,
    Benchpress = 4
}

GetOff.eSide = {
    Left = 1,
    Right = 2
}