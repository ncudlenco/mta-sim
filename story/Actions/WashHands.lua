WashHands = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " washes ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function WashHands:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description  .. self.Performer:getData('genderGenitive') .. " hands in the " .. self.TargetItem.Description, self.Performer)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    math.randomseed(os.time())
    time = math.random(2000, 5000)
    self.Performer:setAnimation("INT_HOUSE", "wash_up", time, true, true, false, true)

    if DEBUG then
        outputConsole("WashHands:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function WashHands:GetDynamicString()
    return 'return WashHands{}'
end