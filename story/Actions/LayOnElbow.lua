LayOnElbow = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is laying on the elbow ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function LayOnElbow:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description, self.Performer)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Bored_Loop", 5000, true, true, false, true)

    if DEBUG then
        outputConsole("LayOnElbow:Apply")
    end

    OnGlobalActionFinished(5000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end