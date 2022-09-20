Hug = class(StoryActionBase, function(o, params)
    params.description = " hug each other "
    params.name = 'Hug'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function Hug:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    local function faceP1ToP2(p1, p2)
        local targetFront = p2.position - p1.position
        local angle = p1.matrix.forward:angleAboutAxis(targetFront, p1.matrix.up)
        p1.rotation = Vector3(0,0,p1.rotation.z + math.deg(angle))
    end
    StoryActionBase.Apply(self)

    self.TargetPlayer.position = self.Performer.position + Vector3(-0.5,-0.5,0)

    faceP1ToP2(self.Performer, self.TargetPlayer)
    faceP1ToP2(self.TargetPlayer, self.Performer)

    local time = 2400
    StoryActionBase.GetLogger(self, story):Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

    self.Performer:setAnimation("gangs", "hndshkfa_swt", time, true, false, false, false)
    self.TargetPlayer:setAnimation("gangs", "hndshkfa_swt", time, true, false, false, false)

    if DEBUG then
        outputConsole("Hug:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
    OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
end

function Hug:GetDynamicString()
    return 'return Hug{}'
end