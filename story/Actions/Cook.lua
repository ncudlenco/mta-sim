Cook = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is cooking food ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function Cook:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    story.Logger.Log(self.Performer:getData('skinDescription') + self.Description + " at the " + self.TargetItem.Description)
    self.Performer:setAnimation("INT_HOUSE", "wash_up", 3000, true, false, false, true);
    sleep(3000)
    self.Performer:setAnimation()
    self.NextLocation:GetNextValidAction(self.Performer):Apply()
end