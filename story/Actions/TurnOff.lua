TurnOff = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " turns off the ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function TurnOff:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    self.Performer:setAnimation("INT_SHOP", "shop_loop", 500, true, true, false, true)

    if DEBUG then
        outputConsole("TurnOff:Apply")
    end

    OnGlobalActionFinished(500, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TurnOff:GetDynamicString()
    return 'return TurnOff{}'
end