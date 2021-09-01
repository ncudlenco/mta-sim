Laugh = class(StoryActionBase, function(o, params)
    params.description = PickRandom(" laughs at ", " is laughing ")
    params.name = 'Laugh'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function Laugh:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    local function faceP1ToP2(p1, p2)
        local targetFront = p2.position - p1.position
        local angle = p1.matrix.forward:angleAboutAxis(targetFront, p1.matrix.up)
        p1.rotation = Vector3(0,0,p1.rotation.z + math.deg(angle))
    end
    
    self.TargetPlayer.position = self.Performer.position + Vector3(-0.5,-0.5,0)

    faceP1ToP2(self.Performer, self.TargetPlayer)
    faceP1ToP2(self.TargetPlayer, self.Performer)

    local time = random(5000, 16000)
    story.Logger:Log(self.Description .. self.TargetItem:getData('name') .. " joke", self)
    self.Performer:setAnimation("rapping", "laugh_01", time, true, false, false, false)
    self.TargetPlayer:setAnimation("rapping", "laugh_01", time, true, false, false, false)

    if DEBUG then
        outputConsole("Laugh:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
    OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
end

function Laugh:GetDynamicString()
    return 'return Laugh{}'
end