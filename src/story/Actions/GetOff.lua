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

    -- Clear furniture flag - actor is getting off
    self.Performer:setData('isOnFurniture', false)

    -- Cleanup benchpress object if this is interrupting a benchpress workout
    local cleanupData = self.Performer:getData('benchpress_cleanup')
    if cleanupData then
        detachElementFromBone(cleanupData.object)
        setElementPosition(cleanupData.object, cleanupData.position)
        setElementRotation(cleanupData.object, cleanupData.rotation)
        self.Performer:setData('benchpress_cleanup', nil)
    end

    -- Re-enable collisions between this actor and all other peds when getting off
    -- triggerClientEvent("onEnablePedToPedCollisions", getRootElement(), self.Performer)

    local block = ""
    local animation = ""
    local updatePedPosition = true
    local time = 0

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

    -- Delay animation to allow rotation to be applied
    Timer(function()
        if self.Performer and isElement(self.Performer) then
            self.Performer:setAnimation(block, animation, time, false, updatePedPosition, false, true)
        end
    end, 100, 1)

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