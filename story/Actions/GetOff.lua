GetOff = class(StoryActionBase, function(o, params)
    params.description = " gets off the "
    params.name = 'GetOff'

    StoryActionBase.init(o, params)
    o.how = params.how
    o.side = params.side or GetOff.eSide.Left
end)


function GetOff:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    -- self.TargetItem.instance:setCollisionsEnabled(false)

    local block = ""
    local animation = ""
    local updatePedPosition = true

    if self.how == GetOff.eHow.Bed then
        time = 2800
        block = "INT_HOUSE"

        if self.side == GetOff.eSide.Left then
            animation = "BED_Out_L"
        elseif self.side == GetOff.eSide.Right then
            animation = "BED_Out_R"
        end
        self.Performer.rotation = self.Performer.rotation + Vector3(0,0,180)

    elseif self.how == GetOff.eHow.GymBike then
        time = 1600
        block = "GYMNASIUM"
        animation = "gym_bike_getoff"
    elseif self.how == GetOff.eHow.Treadmill then
        time = 3200
        block = "GYMNASIUM"
        animation = "gym_tread_getoff"
        updatePedPosition = false
    elseif self.how == GetOff.eHow.BenchPress then
        time = 8000
        block = "benchpress"
        animation = "gym_bp_getoff"
        updatePedPosition = false
    end

    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description, self)
    self.Performer:setAnimation(block, animation, time, false, updatePedPosition, false, true)

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
    BenchPress = 4
}

GetOff.eSide = {
    Left = 1,
    Right = 2
}