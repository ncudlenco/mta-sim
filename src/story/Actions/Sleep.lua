Sleep = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts sleeping on it", " sleeps on it"})
    params.name = 'Sleep'

    StoryActionBase.init(o,params)
    o.how = params.how or Sleep.eHow.Left
end)

function Sleep:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self, false, true, {" wakes up ", " finishes sleeping "})
    -- self.TargetItem.instance:setCollisionsEnabled(false)
    -- self.Performer.rotation = self.Performer.rotation + Vector3(0,0,180)

    local setupTime = 3000

    -- -- Set indefinite looping animation
    -- if self.how == Sleep.eHow.Left then
    --     self.Performer:setAnimation("INT_HOUSE", "BED_Loop_L", -1, true, true, true, true)
    -- elseif self.how == Sleep.eHow.Right then
    --     self.Performer:setAnimation("INT_HOUSE", "BED_Loop_R", -1, true, true, true, true)
    -- end

    if DEBUG then
        outputConsole("Sleep:Apply")
    end

    OnGlobalActionFinished(setupTime, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Sleep:GetDynamicString()
    return 'return Sleep{how = '..self.how..'}'
end

Sleep.eHow = {
    Left = 1,
    Right = 2
}