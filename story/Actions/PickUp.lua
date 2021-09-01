PickUp = class(StoryActionBase, function(o, params)
    params.description = " picks up "
    params.name = 'PickUp'

    StoryActionBase.init(o,params)
    o.Where = params.where
    o.TargetObjectExists = params.targetObjectExists or true
    o.how = params.how or PickUp.eHow.Normal
    o.hand = params.hand or PickUp.eHand.Right
end)

function PickUp:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if not self.TargetObjectExists then
        self.TargetItem:Create()
    end

    pickedObjects = self.Performer:getData('pickedObjects')

    if type(pickedObjects) == 'boolean' then
        pickedObjects = {}
    end
    
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

    outputChatBox("PickUp:Apply - HEREEEEE")
    
    if sameObject then
        story.Logger:Log(self.Description .. "the same ".. self.TargetItem.Description .. " from " .. self.Where, self)
    elseif sameDescription then
        story.Logger:Log(self.Description .. "another " .. self.TargetItem.Description .. " from " .. self.Where, self)
    else
        story.Logger:Log(self.Description .. getWordPrefix(self.TargetItem.Description) .. " " .. self.TargetItem.Description .. " from " .. self.Where, self)
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
        time = 2500
        self.Performer:setAnimation("freeweights", "gym_free_pickup", time, true, false, false, true)
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        attachElementToBone(self.TargetItem.instance, self.Performer, self.hand, 
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)
    end)

    table.insert(pickedObjects, {self.TargetItem.ObjectId, self.TargetItem.Description})
    self.Performer:setData('pickedObjects', pickedObjects)
end

function PickUp:GetDynamicString()
    return 'return PickUp{where = "'..self.Where..'", targetObjectExists = '.. tostring(self.TargetObjectExists) ..', hand = '..self.hand..', how = '..self.how..'}'
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