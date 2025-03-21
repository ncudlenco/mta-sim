WashHands = class(StoryActionBase, function(o, params)
    params.description = " washes "
    params.name = 'WashHands'

    StoryActionBase.init(o,params)
end)

function WashHands:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description  .. self.Performer:getData('genderGenitive') .. " hands in the " .. self.TargetItem.Description, self)

    local time = random(2000, 8000)
    self.Performer:setAnimation("INT_HOUSE", "wash_up", time, true, true, false, true)

    if DEBUG then
        outputConsole("WashHands:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function WashHands:GetDynamicString()
    return 'return WashHands{}'
end