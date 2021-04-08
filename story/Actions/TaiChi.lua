TaiChi = class(StoryActionBase, function(o, params)
    params.description = " starts doing tai chi "
    StoryActionBase.init(o,params)
end)

function TaiChi:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description, self)
    end
    self.Performer:setAnimation("PARK", "Tai_Chi_in", 3000, true, true, false, true)

    time = random(8000, 15000)

    self.Performer:setAnimation("PARK", "Tai_Chi_Loop", time, true, true, false, true)

    if DEBUG then
        outputConsole("TaiChi:Apply")
    end

    OnGlobalActionFinished(3000 + time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TaiChi:GetDynamicString()
    return 'return TaiChi{}'
end