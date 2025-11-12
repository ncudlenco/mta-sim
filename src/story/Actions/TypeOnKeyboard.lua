TypeOnKeyboard = class(StoryActionBase, function(o, params)
    params.description = " types "
    params.name = 'TypeOnKeyboard'

    StoryActionBase.init(o,params)
end)

function TypeOnKeyboard:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. " on the " .. self.TargetItem.Description, self)

    local setupTime = random(5000, 10000)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Type_Loop", -1, true, true, true, true)
    if DEBUG then
        outputConsole("TypeOnKeyboard:Apply")
    end

    OnGlobalActionFinished(setupTime, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TypeOnKeyboard:GetDynamicString()
    return 'return TypeOnKeyboard{}'
end