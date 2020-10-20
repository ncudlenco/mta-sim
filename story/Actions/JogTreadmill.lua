JogTreadmill = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, PickRandom({" starts jogging on the ", " jogs on the"}), params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = JogTreadmill.eHow[PickRandom(JogTreadmill.eHow)]
end)

function JogTreadmill:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if self.how == JogTreadmill.eHow.Slow then
        self.Description = PickRandom({" starts walking on the ", " walks on the "})
    elseif self.how == JogTreadmill.eHow.Normal then
        self.Description = PickRandom({" starts running on the ", " runs on the "})
    elseif self.how == JogTreadmill.eHow.Fast then
        self.Description = PickRandom({" starts sprinting on the ", " sprints on the "})
    end
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)

    math.randomseed(os.time())
    local time = math.random(8000, 18000)
    self.Performer:setAnimation("GYMNASIUM", self.how, time, true, false, false, true)

    if DEBUG then
        outputConsole("JogTreadmill:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        
    end)
end

function JogTreadmill:GetDynamicString()
    return 'return JogTreadmill{how = '..self.how..'}'
end

JogTreadmill.eHow = 
{
    Slow = "gym_tread_walk",
    Normal = "gym_tread_jog",
    Fast = "gym_tread_sprint"
}