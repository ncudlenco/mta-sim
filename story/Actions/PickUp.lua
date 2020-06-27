PickUp = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " picks up ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function PickUp:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    self.Performer:setAnimation("INT_SHOP", "shop_loop", 500, true, true, false, true)
    attachElementToBone(self.TargetItem.instance, self.Performer, 12, 
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)

    if DEBUG then
        outputConsole("PickUp:Apply")
    end

    OnGlobalActionFinished(500, self.Performer:getData('id'), self.Performer:getData('storyId'))
end