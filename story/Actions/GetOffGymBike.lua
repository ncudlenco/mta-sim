GetOffGymBike = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " gets off ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function GetOffGymBike:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation("GYMNASIUM", "gym_bike_getoff", 1600, true, true, false, true)

    if DEBUG then
        outputConsole("GetOffGymBike:Apply")
    end

    OnGlobalActionFinished(1600, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end

function GetOffGymBike:GetDynamicString()
    return 'return GetOffGymBike{}'
end