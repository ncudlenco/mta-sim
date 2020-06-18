Sleep = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is sleeping ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function Sleep:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " on the " .. self.TargetItem.Description, self.Performer)
    self.TargetItem.instance:setCollisionsEnabled(false)
    self.Performer.rotation = self.Performer.rotation + Vector3(0,0,180)
    self.Performer:setAnimation("INT_HOUSE", "BED_Loop_L", 3000, true, true, false, true)
    if DEBUG then
        outputConsole("Sleep:Apply")
    end

    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end