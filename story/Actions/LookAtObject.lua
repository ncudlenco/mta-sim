LookAtObject = class(StoryActionBase, function(o, params)
    params.description = " is looking at "
    StoryActionBase.init(o,params)
end)

function LookAtObject:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description .. " the " .. self.TargetItem.Description, self)
    end
    
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