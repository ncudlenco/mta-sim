GetOffBed = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " gets off ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function GetOffBed:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " the " .. self.TargetItem.Description, self.Performer)

    self.TargetItem.instance:setCollisionsEnabled(false)
    self.Performer:setAnimation("INT_HOUSE", "BED_Out_L", -1, false, true, false, true)
    if DEBUG then
        outputConsole("GetOffBed:Apply")
    end

    OnGlobalActionFinished(5000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end