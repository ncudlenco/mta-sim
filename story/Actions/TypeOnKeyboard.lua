TypeOnKeyboard = class(StoryActionBase, function(o, params)
    params.description = " types "
    StoryActionBase.init(o,params)
end)

function TypeOnKeyboard:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description .. " on the " .. self.TargetItem.Description, self)
    end

    time = random(4000, 12000)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Type_Loop", time, true, true, false, true)
    if DEBUG then
        outputConsole("TypeOnKeyboard:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TypeOnKeyboard:GetDynamicString()
    return 'return TypeOnKeyboard{}'
end