WashHands = class(StoryActionBase, function(o, params)
    params.description = " washes "
    StoryActionBase.init(o,params)
end)

function WashHands:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Description  .. self.Performer:getData('genderGenitive') .. " hands in the " .. self.TargetItem.Description, self)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    time = random(2000, 8000)
    self.Performer:setAnimation("INT_HOUSE", "wash_up", time, true, true, false, true)

    if DEBUG then
        outputConsole("WashHands:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function WashHands:GetDynamicString()
    return 'return WashHands{}'
end