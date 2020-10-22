BenchpressWorkOut = class(StoryActionBase, function(o, params)
    params.description = " works out at the "
    StoryActionBase.init(o, params)
end)

function BenchpressWorkOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    math.randomseed(os.time())
    local time = math.random(8000, 18000)
    story.Logger:Log(self.Description .. self.TargetItem.Description, self, false, true, {"finishes", "finishes working out"})
    
    self.Performer:setAnimation("benchpress", "gym_bp_up_A", time, true, false, false, true)

    if DEBUG then
        outputConsole("BenchpressWorkOut:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function BenchpressWorkOut:GetDynamicString()
    return 'return BenchpressWorkOut{}'
end