LookAtObject = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is looking at ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function LookAtObject:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " the " .. self.TargetItem.Description, self.Performer)
    
    local playerEyesPosition = self.Performer.position + self.Performer.matrix.up * 1.2
    self.Performer:setCameraMatrix(playerEyesPosition, self.TargetItem.position)

    if DEBUG then
        outputConsole("LookAtObject:Apply")
    end

    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        self.Performer.cameraTarget = nil
    end)
end