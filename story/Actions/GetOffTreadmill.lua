GetOffTreadmill = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " gets off ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function GetOffTreadmill:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation("GYMNASIUM", "gym_tread_getoff", 3200, true, true, false, true)

    if DEBUG then
        outputConsole("GetOffTreadmill:Apply")
    end

    OnGlobalActionFinished(3200, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end

function GetOffTreadmill:GetDynamicString()
    return 'return GetOffTreadmill{}'
end