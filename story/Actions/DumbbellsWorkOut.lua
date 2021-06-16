DumbbellsWorkOut = class(StoryActionBase, function(o, params)
    params.name = 'DumbbellsWorkOut'
    params.description = " starts working out with the "

    StoryActionBase.init(o, params)
end)

function DumbbellsWorkOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    end
    
    local time = random(8000, 18000)
    self.Performer:setAnimation("freeweights", "gym_free_a", time, true, false, false, true)

    if DEBUG then
        outputConsole("DumbbellsWorkOut:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function DumbbellsWorkOut:GetDynamicString()
    return 'return DumbbellsWorkOut{}'
end