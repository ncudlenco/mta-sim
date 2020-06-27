Wait = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is waiting ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.Time = params.time
end)

function Wait:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description, self.Performer)
    sleep(o.Time)

    if DEBUG then
        outputConsole("Wait:Apply")
    end

    OnGlobalActionFinished(self.Time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end