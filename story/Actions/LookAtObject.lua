LookAtObject = class(StoryActionBase, function(o, params)
    params.description = " is looking at "
    params.name = 'LookAtObject'

    StoryActionBase.init(o,params)
end)

function LookAtObject:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. " the " .. self.TargetItem.Description, self)

    local playerEyesPosition = self.Performer.position + self.Performer.matrix.up * 1.2
    self.Performer:setCameraMatrix(playerEyesPosition, self.TargetItem.position)

    if DEBUG then
        outputConsole("LookAtObject:Apply")
    end

    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        self.Performer.cameraTarget = nil
    end)
end

function LookAtObject:GetDynamicString()
    return 'return LookAtObject{}'
end