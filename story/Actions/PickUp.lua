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
    
    if self.TargetObjectExists then
        self.TargetItem:Destroy()
    end

    self.TargetItem:Create()
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description .. " from " .. self.Where, self.Performer)
    
    if self.how == PickUp.eHow.Normal then
        time = 200
        self.TargetItem:updatePositionOffsetStandUp()
        self.TargetItem:updateRotOffsetStandUp()
        self.Performer:setAnimation("BAR", "Barserve_bottle", time, true, true, false, true)
    elseif self.how == PickUp.eHow.Down then
        time = 500
        self.Performer:setAnimation("MISC", "Case_pickup", 500, true, true, false, true)
    elseif self.how == PickUp.eHow.Sit then
        time = 500
        self.TargetItem:updatePositionOffsetSitDown()
        self.TargetItem:updateRotOffsetSitDown()
        self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Drink", 500, true, true, false, true)
    end

    if DEBUG then
        outputConsole("PickUp:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        attachElementToBone(self.TargetItem.instance, self.Performer, self.hand, 
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)
    end)
end

PickUp.eHow = {
    Normal = 1,
    Down = 2,
    Sit = 3
}

PickUp.eHand = {
    Left = 11,
    Right = 12
}