TypeOnKeyboard = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is typing ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function TypeOnKeyboard:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " on the " .. self.TargetItem.Description, self.Performer)

    math.randomseed(os.time())
    time = math.random(4000, 12000)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Type_Loop", time, true, true, false, true)
    if DEBUG then
        outputConsole("TypeOnKeyboard:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end