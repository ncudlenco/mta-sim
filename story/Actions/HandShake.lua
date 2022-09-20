HandShake = class(StoryActionBase, function(o, params)
    params.description = " shake their hands"
    params.name = 'HandShake'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function HandShake:Apply()
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

    local time = 2000
    StoryActionBase.GetLogger(self, story):Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

    local shakeType = PickRandom({"hndshkaa", "hndshkda", "hndshkfa", "prtial_hndshk_biz_01"})
    self.Performer:setAnimation("gangs", shakeType, time, true, false, false, false)
    self.TargetPlayer:setAnimation("gangs", shakeType, time, true, false, false, false)

    if DEBUG then
        outputConsole("HandShake:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
    OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))

end

function HandShake:GetDynamicString()
    return 'return HandShake{}'
end