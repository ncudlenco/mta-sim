PickUp = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " picks up ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.Where = params.where
    o.TargetObjectExists = params.targetObjectExists
    o.how = params.how or PickUp.eHow.Normal
    o.hand = params.hand or PickUp.eHand.Right
end)

function PickUp:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    print(self.TargetObjectExists)
    if self.TargetObjectExists then
        self.TargetItem:Destroy()
    end

    pickedObjects = self.Performer:getData('pickedObjects')
    
    sameDescription = false
    sameObject = false

    for i, value in ipairs(pickedObjects) do
        if value[1] == self.TargetItem.ObjectId then
            sameObject = true
        end

        if value[2] == self.TargetItem.Description then
            sameDescription = true
        end
    end
    
    if sameObject then
        story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. "the same ".. self.TargetItem.Description .. " from " .. self.Where, self.Performer)
    elseif sameDescription then
        story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. "another " .. self.TargetItem.Description .. " from " .. self.Where, self.Performer)
    else
        story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. getWordPrefix(self.TargetItem.Description) .. " " .. self.TargetItem.Description .. " from " .. self.Where, self.Performer)
    end

    local time = 500
    if self.how == PickUp.eHow.Normal then
        time = 200
        self.TargetItem:updatePositionOffsetStandUp()
        self.TargetItem:updateRotOffsetStandUp()
        self.Performer:setAnimation("BAR", "Barserve_bottle", time, true, true, false, true)
    elseif self.how == PickUp.eHow.Down then
        self.Performer:setAnimation("MISC", "Case_pickup", time, true, true, false, true)
    elseif self.how == PickUp.eHow.Sit then
        self.TargetItem:updatePositionOffsetSitDown()
        self.TargetItem:updateRotOffsetSitDown()
        self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Drink", time, true, true, false, true)
    elseif self.how == PickUp.eHow.FloorBarbell then
        self.Performer:setAnimation("Freeweights", "gym_free_pickup", time, true, true, false, true)
    end

    if DEBUG then
        outputConsole("PickUp:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        self.TargetItem:Create()
        attachElementToBone(self.TargetItem.instance, self.Performer, self.hand, 
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)
    end)

    table.insert(pickedObjects, {self.TargetItem.ObjectId, self.TargetItem.Description})
    self.Performer:setData('pickedObjects', pickedObjects)
end

function PickUp:GetDynamicString()
    local TargetObjectExistsStr = 'false'
    if self.TargetObjectExists then
        TargetObjectExistsStr = 'true'
    end
    return 'return PickUp{where = "'..self.Where..'", targetObjectExists = '.. TargetObjectExistsStr ..', hand = '..self.hand..', how = '..self.how..'}'
end

PickUp.eHow = {
    Normal = 1,
    Down = 2,
    Sit = 3,
    FloorBarbell = 4
}

PickUp.eHand = {
    Left = 11,
    Right = 12
}