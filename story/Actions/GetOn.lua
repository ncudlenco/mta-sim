GetOn = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " gets on the ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = params.how
    o.side = params.side or GetOn.eSide.Left
end)

function GetOn:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
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

    local block = ""
    local animation = ""
    
    if self.how == GetOn.eHow.Bed then
        time = 3500
        block = "INT_HOUSE"

        if self.how == GetOn.eSide.Left then
            animation = "BED_In_L"
        elseif self.how == GetOn.eSide.Right then
            animation = "BED_In_R"
        end
    elseif self.how == GetOn.eHow.GymBike then
        time = 1600
        block = "GYMNASIUM"
        animation = "gym_bike_geton"
    elseif self.how == GetOn.eHow.Treadmill then
        time = 3200
        block = "GYMNASIUM"
        animation = "gym_tread_geton"
    elseif self.how == GetOn.eHow.Benchpress then
        time = 4000
        block = "GYMNASIUM"
        animation = "gym_bp_geton"
    end

    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation(block, animation, time, true, true, false, true)

    if DEBUG then
        outputConsole("GetOn:Apply")
    end
    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function GetOn:GetDynamicString()
    return 'return GetOn{how = '..self.how..'}'
end


GetOn.eHow = {
    Bed = 1,
    GymBike = 2,
    Treadmill = 3,
    Benchpress = 4
}

GetOn.eSide = {
    Left = 1,
    Right = 2
}