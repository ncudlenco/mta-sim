Kiss = class(StoryActionBase, function(o, params)
    params.description = " kiss each other "
    params.name = 'Kiss'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function Kiss:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    
    local function faceP1ToP2(p1, p2)
        local targetFront = p2.position - p1.position
        local angle = p1.matrix.forward:angleAboutAxis(targetFront, p1.matrix.up)
        p1.rotation = Vector3(0,0,p1.rotation.z + math.deg(angle))
    end
    
    self.TargetPlayer.position = self.Performer.position + Vector3(-0.7,-0.7,0)
    
    faceP1ToP2(self.Performer, self.TargetPlayer)
    faceP1ToP2(self.TargetPlayer, self.Performer)

    
    local time = 4000
    story.Logger:Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

    local performerKissType = nil
    local targetKissType = nil

    if self.Performer:getData('genderNominative') == "he" then
        performerKissType = PickRandom({"playa_kiss_01", "playa_kiss_02", "playa_kiss_03"})
    else
        performerKissType = PickRandom({"grlfrd_kiss_01", "grlfrd_kiss_02", "grlfrd_kiss_03"})
        --reject kiss ; -0.7 | hugged hiss ; -0.7 | intermediate kiss
    end
    if self.TargetPlayer:getData('genderNominative') == "he" then
        targetKissType = PickRandom({"playa_kiss_01", "playa_kiss_02", "playa_kiss_03"})
    else
        targetKissType = PickRandom({"grlfrd_kiss_01", "grlfrd_kiss_02", "grlfrd_kiss_03"})
    end

    self.Performer:setAnimation("kissing", "playa_kiss_01", time, true, false, false, false)
    self.TargetPlayer:setAnimation("kissing", "grlfrd_kiss_01", time, true, false, false, false)

    if DEBUG then
        outputConsole("Kiss:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
    OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
end

function Kiss:GetDynamicString()
    return 'return Kiss{}'
end