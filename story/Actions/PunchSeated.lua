PunchSeated = class(StoryActionBase, function(o, params)
    params.description = " punches the desk "
    StoryActionBase.init(o,params)
end)

function PunchSeated:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description, self)
    end
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Crash", -1, false, true, false, true)

    if DEBUG then
        outputConsole("PunchSeated:Apply")
    end

    OnGlobalActionFinished(5000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function PunchSeated:GetDynamicString()
    return 'return PunchSeated{}'
end