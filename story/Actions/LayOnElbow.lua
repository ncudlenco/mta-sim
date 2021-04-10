LayOnElbow = class(StoryActionBase, function(o, params)
    params.description = " lays "
    StoryActionBase.init(o, params)
end)

function LayOnElbow:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description  .. self.Performer:getData('genderGenitive') ..  " head on the elbow", self)
    end
    time = random(3000, 8000)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Bored_Loop", time, true, true, false, true)

    if DEBUG then
        outputConsole("LayOnElbow:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function LayOnElbow:GetDynamicString()
    return 'return LayOnElbow{}'
end