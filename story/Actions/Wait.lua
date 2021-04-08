Wait = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" is waiting for something ", " is looking around "})
    StoryActionBase.init(o,params)
    o.Time = params.time
end)

function Wait:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description, self)
    end

    self.Performer:setAnimation("cop_ambient", "coplook_loop", self.Time, true, false, false, true)

    if DEBUG then
        outputConsole("Wait:Apply")
    end

    OnGlobalActionFinished(self.Time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Wait:GetDynamicString()
    return 'return Wait{}'
end