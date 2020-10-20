HangUp = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " hangs up", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function HangUp:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description, self.Performer)
    self.Performer:setAnimation("PED", "PHONE_OUT", 2000, true, true, false, true)

    if DEBUG then
        outputConsole("HangUp:Apply")
    end

    OnGlobalActionFinished(2000, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end

function HangUp:GetDynamicString()
    return 'return HangUp{}'
end