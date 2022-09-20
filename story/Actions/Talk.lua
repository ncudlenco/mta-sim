Talk = class(StoryActionBase, function(o, params)
    params.description = " talks to "
    params.name = 'Talk'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function Talk:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    local function faceP1ToP2(p1, p2)
        local targetFront = p2.position - p1.position
        local angle = p1.matrix.forward:angleAboutAxis(targetFront, p1.matrix.up)
        p1.rotation = Vector3(0,0,p1.rotation.z + math.deg(angle))
    end

    self.TargetPlayer.position = self.Performer.position + Vector3(-0.5,-0.5,0)

    faceP1ToP2(self.Performer, self.TargetPlayer)
    faceP1ToP2(self.TargetPlayer, self.Performer)
    local time = math.random(2, 4) * 1000

    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetPlayer:getData('name'), self)
    local talkType = PickRandom({"prtial_gngtlka", "prtial_gngtlkb", "prtial_gngtlkc",
                                 "prtial_gngtlkd", "prtial_gngtlke", "prtial_gngtlkf",
                                 "prtial_gngtlkg", "prtial_gngtlkh"})
    self.Performer:setAnimation("gangs", talkType, time, true, false, false, false)
    talkType = PickRandom({"prtial_gngtlka", "prtial_gngtlkb", "prtial_gngtlkc",
                                 "prtial_gngtlkd", "prtial_gngtlke", "prtial_gngtlkf",
                                 "prtial_gngtlkg", "prtial_gngtlkh"})
    self.TargetPlayer:setAnimation("gangs", talkType, time, true, false, false, false)


    if DEBUG then
        outputConsole("Talk:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
    OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
end

function Talk:GetDynamicString()
    return 'return Talk{}'
end