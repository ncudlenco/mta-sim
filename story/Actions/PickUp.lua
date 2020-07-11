PickUp = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " picks up ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.Where = params.where
    o.TargetObjectExists = params.targetObjectExists
    o.how = params.how or PickUp.eHow.Normal
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
        self.Performer:setAnimation("INT_SHOP", "shop_loop", 500, true, true, false, true)
    elseif self.how == PickUp.eHow.Down then
        self.Performer:setAnimation("MISC", "Case_pickup", 500, true, true, false, true)
    end

    attachElementToBone(self.TargetItem.instance, self.Performer, 12, 
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)

    if DEBUG then
        outputConsole("PickUp:Apply")
    end

    OnGlobalActionFinished(500, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

PickUp.eHow = {
    Normal = 1,
    Down = 2
}