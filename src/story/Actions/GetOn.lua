GetOn = class(StoryActionBase, function(o, params)
    params.description = " gets{temp}on the "
    params.name = 'GetOn'

    StoryActionBase.init(o, params)
    o.how = params.how
    o.side = params.side or GetOn.eSide.Left
end)

function GetOn:Apply()
    local id = self.Performer:getData('id')
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    -- Disable collisions between this actor and all other peds when getting on furniture
    triggerClientEvent("onDisablePedToPedCollisions", getRootElement(), self.Performer)

    if DEBUG then
        outputConsole("GetOn:Apply")
    end

    local block = ""
    local animation = ""
    local updatePedPosition = true
    local time = 3100

    if self.how == GetOn.eHow.Bed then
        time = 3100
        block = "INT_HOUSE"

        -- Ensure actor rotation matches POI angle before bed animation
        -- This fixes rotation corruption from previous GetOff actions (+180 offset)
        if self.NextLocation and self.NextLocation.rotation then
            self.Performer.rotation = self.NextLocation.rotation
        end

        if self.side == GetOn.eSide.Left then
            animation = "BED_In_L"
        elseif self.side == GetOn.eSide.Right then
            animation = "BED_In_R"
        end
    elseif self.how == GetOn.eHow.GymBike then
        time = 1300
        block = "GYMNASIUM"
        animation = "gym_bike_geton"
        updatePedPosition = false
    elseif self.how == GetOn.eHow.Treadmill then
        time = 1600
        block = "GYMNASIUM"
        animation = "gym_tread_geton"
        updatePedPosition = false
    elseif self.how == GetOn.eHow.BenchPress then
        time = 4000
        block = "benchpress"
        animation = "gym_bp_geton"
        updatePedPosition = false
    end

    local selfDescription = ''
    if self.Buffer[id] then
        if self.Buffer[id] == self.TargetItem then
            selfDescription = self.Description:gsub('{temp}', ' back ')
            selfDescription = selfDescription .. 'same '
        else
            selfDescription = self.Description:gsub('{temp}', ' ')
            if self.Buffer[id].type and self.TargetItem.type and self.Buffer[id].type == self.TargetItem.type then
                selfDescription = selfDescription:gsub('the', PickRandom({'a different ', 'another '}))
            end
        end
    else
        selfDescription = self.Description:gsub('{temp}', ' ')
    end
    StoryActionBase.GetLogger(self, story):Log(selfDescription .. self.TargetItem.Description, self)
    self.Performer:setAnimation(block, animation, time, false, updatePedPosition, false, true)

    self.Buffer[id] = self.TargetItem
    if DEBUG then
        outputConsole("GetOn:Apply")
    end
    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function GetOn:GetDynamicString()
    return 'return GetOn{how = '..self.how..','..'side = '..self.side..'}'
end

GetOn.eHow = {
    Bed = 1,
    GymBike = 2,
    Treadmill = 3,
    BenchPress = 4
}

GetOn.eSide = {
    Left = 1,
    Right = 2
}