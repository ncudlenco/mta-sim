GetInBed = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is getting in ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function GetInBed:Apply()
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
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " the " .. self.TargetItem.Description, self.Performer)
    -- player.Position = new Vector3(centerTopLeft.X, centerTopLeft.Y, player.Position.Z);
    self.TargetItem.instance:setCollisionsEnabled(false)
    self.Performer:setAnimation("INT_HOUSE", "BED_In_L", -1, false, true, false, true)
    if DEBUG then
        outputConsole("GetInBed:Apply")
    end
    OnGlobalActionFinished(8000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end