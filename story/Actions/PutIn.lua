PutIn = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " puts ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.Where = params.where
end)

function PutIn:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description .. " in " .. self.Where, self.Performer)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    self.Performer:setAnimation("INT_SHOP", "shop_loop", 500, true, true, false, true)
    detachElementFromBone(self.TargetItem.instance)
    self.TargetItem:Destroy()

    if DEBUG then
        outputConsole("PutIn:Apply")
    end

    OnGlobalActionFinished(500, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function PutIn:GetDynamicString()
    return 'return PutIn{where = "'..self.Where..'", how = '..self.how..'}'
end