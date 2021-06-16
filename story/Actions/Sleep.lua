Sleep = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts sleeping on it", " sleeps on it"})
    params.name = 'Sleep'

    StoryActionBase.init(o,params)
    o.how = params.how or Sleep.eHow.Left
end)

function Sleep:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description, self, false, true, {" wakes up ", " finishes sleeping "})
    end
    -- self.TargetItem.instance:setCollisionsEnabled(false)
    self.Performer.rotation = self.Performer.rotation + Vector3(0,0,180)

    local time = random(3000, 18000)
    if self.how == Sleep.eHow.Left then
        self.Performer:setAnimation("INT_HOUSE", "BED_Loop_L", time, true, true, false, true)
    elseif self.how == Sleep.eHow.Right then
        self.Performer:setAnimation("INT_HOUSE", "BED_Loop_R", time, true, true, false, true)
    end
    
    if DEBUG then
        outputConsole("Sleep:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Sleep:GetDynamicString()
    return 'return Sleep{how = '..self.how..'}'
end

Sleep.eHow = {
    Left = 1,
    Right = 2
}