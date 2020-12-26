BarbellWorkOut = class(StoryActionBase, function(o, params)
    params.description = " works out with "
    StoryActionBase.init(o, params)
end)

function BarbellWorkOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    local time = random(7000, 19000)
    story.Logger:Log(self.Description .. self.TargetItem.Description, self, false, true, {"finishes", "finishes working out"})
    
    self.Performer:setAnimation("Freeweights", "gym_free_A", time, true, false, false, true)

    if DEBUG then
        outputConsole("BarbellWorkOut:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function BarbellWorkOut:GetDynamicString()
    return 'return BarbellWorkOut{}'
end