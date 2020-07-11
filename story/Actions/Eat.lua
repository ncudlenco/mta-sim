Eat = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is eating ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function Eat:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " a "  .. self.TargetItem.Description, self.Performer)

    self.Performer:setAnimation("FOOD", "FF_Sit_Eat3", 3500, true, true, false, true)

    if DEBUG then
        outputConsole("Eat:Apply")
    end

    OnGlobalActionFinished(3500, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end