Laugh = class(StoryActionBase, function(o, params)
    params.description = PickRandom(" laughs at ", " is laughing ")
    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function Laugh:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    local time = random(5000, 16000)
    story.Logger:Log(self.Description .. self.TargetPlayer:getData('name') .. " joke", self)
    self.Performer:setAnimation("rapping", "laugh_01", time, true, false, false, false)

    if DEBUG then
        outputConsole("Laugh:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Laugh:GetDynamicString()
    return 'return Laugh{}'
end