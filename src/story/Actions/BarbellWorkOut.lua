BarbellWorkOut = class(StoryActionBase, function(o, params)
    params.description = " works out with "
    params.name = 'BarbellWorkOut'
    StoryActionBase.init(o, params)
end)

function BarbellWorkOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)
    
    local setupTime = 3000
    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description, self, false, true, {"finishes", "finishes working out"})

    self.Performer:setAnimation("Freeweights", "gym_free_A", -1, true, false, true, true)

    if DEBUG then
        outputConsole("BarbellWorkOut:Apply")
    end

    OnGlobalActionFinished(setupTime, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function BarbellWorkOut:GetDynamicString()
    return 'return BarbellWorkOut{}'
end