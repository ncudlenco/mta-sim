Kiss = class(StoryActionBase, function(o, params)
    params.description = " kiss each other "
    params.name = 'Kiss'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function Kiss:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    local time = 4000
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)
    end
    local performerKissType = nil
    local targetKissType = nil

    if self.Performer:getData('genderNominative') == "he" then
        performerKissType = PickRandom({"playa_kiss_01", "playa_kiss_02", "playa_kiss_03"})
    else
        performerKissType = PickRandom({"grlfrd_kiss_01", "grlfrd_kiss_02", "grlfrd_kiss_03"})
    end

    self.Performer:setAnimation("kissing", performerKissType, time, true, false, false, false)

    if DEBUG then
        outputConsole("Kiss:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Kiss:GetDynamicString()
    return 'return Kiss{}'
end