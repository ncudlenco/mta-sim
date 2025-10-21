LayOnElbow = class(StoryActionBase, function(o, params)
    params.description = " lays "
    params.name = 'LayOnElbow'

    StoryActionBase.init(o, params)
end)

function LayOnElbow:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description  .. (self.Performer:getData('genderGenitive') or ' the') ..  " head on the elbow", self)

    local setupTime = 3000
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Bored_Loop", -1, true, true, true, true)

    if DEBUG then
        outputConsole("LayOnElbow:Apply")
    end

    OnGlobalActionFinished(setupTime, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function LayOnElbow:GetDynamicString()
    return 'return LayOnElbow{}'
end