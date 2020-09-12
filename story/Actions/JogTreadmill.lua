JogTreadmill = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, PickRandom({" starts jogging on the ", " jogs on the"}), params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = params.how or JogTreadmill.eHow.Normal
end)

function JogTreadmill:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    if self.how == JogTreadmill.eHow.Slow then
        self.Description = " walks on "
    elseif self.how == JogTreadmill.eHow.Normal then
        self.Description = " runs on "
    elseif self.how == JogTreadmill.eHow.Fast then
        self.Description = " sprints on "
    end
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)

    math.randomseed(os.time())
    local time = math.random(8000, 18000)
    self.Performer:setAnimation("GYMNASIUM", self.how, time, true, false, false, true)

    if DEBUG then
        outputConsole("JogTreadmill:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end

function JogTreadmill:GetDynamicString()
    return 'return JogTreadmill{}'
end

JogTreadmill.eHow = 
{
    Slow = "gym_tread_walk",
    Normal = "gym_tread_jog",
    Fast = "gym_tread_sprint"
}