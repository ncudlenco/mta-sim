TurnOff = class(StoryActionBase, function(o, params)
    params.description = " turns off the "
    params.name = 'TurnOff'

    StoryActionBase.init(o,params)
end)

function TurnOff:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description, self)
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