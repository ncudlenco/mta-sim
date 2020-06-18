TypeOnKeyboard = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is typing ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function TypeOnKeyboard:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " on the " .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Type_Loop", -1, true, true, false, true)
    if DEBUG then
        outputConsole("TypeOnKeyboard:Apply")
    end

    OnGlobalActionFinished(5000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end