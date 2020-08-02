Read = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is reading ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function Read:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    math.randomseed(os.time())
    time = math.random(3000, 12000)
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Read", time, true, true, false, true)

    if DEBUG then
        outputConsole("Read:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end