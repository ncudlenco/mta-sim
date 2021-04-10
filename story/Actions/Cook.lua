Cook = class(StoryActionBase, function(o, params)
    params.description = " is cooking food "
    StoryActionBase.init(o, params)
end)

function Cook:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description .. " on the " .. self.TargetItem.Description, self)
    end
    self.Performer:setAnimation("INT_HOUSE", "wash_up", 3000, true, true, false, true)
    if DEBUG then
        outputConsole("WashHands:Apply")
    end

    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Cook:GetDynamicString()
    return 'return Cook{}'
end