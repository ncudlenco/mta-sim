GetOffBed = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " gets off ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = params.how or GetOffBed.eHow.Left
end)

function GetOffBed:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " the " .. self.TargetItem.Description, self.Performer)

    -- self.TargetItem.instance:setCollisionsEnabled(false)

    if self.how == GetOffBed.eHow.Left then
        self.Performer:setAnimation("INT_HOUSE", "BED_Out_L", -1, false, true, false, true)
    elseif self.how == GetOffBed.eHow.Right then
        self.Performer:setAnimation("INT_HOUSE", "BED_Out_R", -1, false, true, false, true)
    end
    
    if DEBUG then
        outputConsole("GetOffBed:Apply")
    end

    OnGlobalActionFinished(5000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

GetOffBed.eHow = {
    Left = 1,
    Right = 2
}