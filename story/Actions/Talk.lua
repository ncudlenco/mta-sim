Talk = class(StoryActionBase, function(o, params)
    params.description = " talks to "
    params.name = 'Talk'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
    o.Time = params.time
end)

function Talk:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description .. self.TargetPlayer:getData('name'), self)
    end

    local talkType = PickRandom({"prtial_gngtlka", "prtial_gngtlkb", "prtial_gngtlkc", 
                                 "prtial_gngtlkd", "prtial_gngtlke", "prtial_gngtlkf", 
                                 "prtial_gngtlkg", "prtial_gngtlkh"})
    self.Performer:setAnimation("gangs", talkType, self.Time, true, false, false, false)

    if DEBUG then
        outputConsole("Talk:Apply")
    end

    OnGlobalActionFinished(self.Time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Talk:GetDynamicString()
    return 'return Talk{}'
end