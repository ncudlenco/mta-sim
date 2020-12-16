GetOn = class(StoryActionBase, function(o, params)
    params.description = " gets{temp}on the "
    StoryActionBase.init(o, params)
    o.how = params.how
    o.side = params.side or GetOn.eSide.Left
end)

function GetOn:Apply()
    local id = self.Performer:getData('id')
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    ----Bounding box is a function for client side only. eventually develop a mechanism to trigger a client side call then send back to 
    ----the server the result and continue with other processes
    -- local theBed = self.TargetItem
    -- local x0, y0, z0, x1, y1, z1 = theBed:getBoundingBox();
    -- local bbox = Extent3(Vector3(x0,y0,z0), Vector3(x1,y1,z1));

    -- bbox:ChangeOrigin(theBed.position, Vector3(0, 0, theBed.Rotation.z));
    -- local centerTopMiddle = Vector3(bbox.Center.X, bbox.Center.Y, bbox.Max.Z);
    -- local across = Vector3.UnitX.Rotate(new Vector3(0, 0, theBed.Rotation.Z));
    -- local centerTopLeft = centerTopMiddle + across.Normalized().Mult((bbox.Max.X - bbox.Min.X) / 2);
    -- player.Position = new Vector3(centerTopLeft.X, centerTopLeft.Y, player.Position.Z);
    --self.TargetItem.instance:setCollisionsEnabled(false)

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
    story.Logger:Log(selfDescription .. self.TargetItem.Description, self)
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