LookAtTheWatch = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " looks at the handwatch ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function LookAtTheWatch:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description, self.Performer)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Watch", -1, false, true, false, true)

    if DEBUG then
        outputConsole("LookAtTheWatch:Apply")
    end

    OnGlobalActionFinished(2000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end