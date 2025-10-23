AnswerPhone = class(StoryActionBase, function(o, params)
    params.description = " answers the "
    params.name = 'AnswerPhone'
    StoryActionBase.init(o, params)
end)

function AnswerPhone:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    -- Object is already attached by TakeOut action
    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description, self)
    self.Performer:setAnimation("PED", "PHONE_IN", 2000, true, true, false, true)

    if DEBUG then
        outputConsole("AnswerPhone:Apply")
    end

    OnGlobalActionFinished(2000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function AnswerPhone:GetDynamicString()
    return 'return AnswerPhone{}'
end