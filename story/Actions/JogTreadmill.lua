JogTreadmill = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts jogging ", " jogs "})
    StoryActionBase.init(o, params)
    o.how = JogTreadmill.eHow[PickRandom(JogTreadmill.eHow)]
end)

function JogTreadmill:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if self.how == JogTreadmill.eHow.Slow then
        self.Description = PickRandom({" starts walking ", " walks "})
    elseif self.how == JogTreadmill.eHow.Normal then
        self.Description = PickRandom({" starts running ", " runs "})
    elseif self.how == JogTreadmill.eHow.Fast then
        self.Description = PickRandom({" starts sprinting ", " sprints "})
    end
    
    story.Logger:Log(self.Description, self)

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