LayOnElbow = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " lays ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function LayOnElbow:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description  .. self.Performer:getData('genderGenitive') ..  " head on the elbow", self.Performer)

    math.randomseed(os.time())
    time = math.random(3000, 8000)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Bored_Loop", time, true, true, false, true)

    if DEBUG then
        outputConsole("LayOnElbow:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function LayOnElbow:GetDynamicString()
    return 'return LayOnElbow{}'
end