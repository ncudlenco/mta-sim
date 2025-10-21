Read = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts reading ", " reads "})
    params.name = 'Read'

    StoryActionBase.init(o,params)
end)

function Read:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    local time = random(3000, 18000)
    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description, self, false, true, {"finishes", "finishes reading"})
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Read", time, true, true, false, true)

    if DEBUG then
        outputConsole("Read:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Read:GetDynamicString()
    return 'return Read{}'
end