DumbbellsWorkOut = class(StoryActionBase, function(o, params)
    params.name = 'DumbbellsWorkOut'
    params.description = " starts working out with the "

    StoryActionBase.init(o, params)
end)

function DumbbellsWorkOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description, self.Performer)

    local setupTime = 3000
    self.Performer:setAnimation("freeweights", "gym_free_a", -1, true, false, true, true)

    if DEBUG then
        outputConsole("DumbbellsWorkOut:Apply")
    end

    OnGlobalActionFinished(setupTime, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function DumbbellsWorkOut:GetDynamicString()
    return 'return DumbbellsWorkOut{}'
end