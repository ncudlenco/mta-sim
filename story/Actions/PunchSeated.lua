PunchSeated = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " punches the desk ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function PunchSeated:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description, self.Performer)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Crash", -1, false, true, false, true)

    if DEBUG then
        outputConsole("PunchSeated:Apply")
    end

    OnGlobalActionFinished(5000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end