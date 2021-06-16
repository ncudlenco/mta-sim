TurnOn = class(StoryActionBase, function(o, params)
    params.description = " turns on the "
    params.name = 'TurnOn'

    StoryActionBase.init(o,params)
end)

function TurnOn:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Description .. self.TargetItem.Description, self)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    self.Performer:setAnimation("INT_SHOP", "shop_loop", 500, true, true, false, true)

    if DEBUG then
        outputConsole("TurnOn:Apply")
    end

    OnGlobalActionFinished(500, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TurnOn:GetDynamicString()
    return 'return TurnOn{}'
end