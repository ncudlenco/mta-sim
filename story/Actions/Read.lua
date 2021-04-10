Read = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts reading ", " reads "})
    StoryActionBase.init(o,params)
end)

function Read:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    local time = random(3000, 18000)
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description .. self.TargetItem.Description, self, false, true, {"finishes", "finishes drinking"})
    end
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Read", time, true, true, false, true)

    if DEBUG then
        outputConsole("Read:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Read:GetDynamicString()
    return 'return Read{}'
end