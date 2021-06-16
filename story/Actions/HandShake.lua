HandShake = class(StoryActionBase, function(o, params)
    params.description = " shake their hands"
    params.name = 'HandShake'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function HandShake:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    local time = 2000
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)
    end
    local shakeType = PickRandom({"hndshkaa", "hndshkda", "hndshkfa", "prtial_hndshk_biz_01"})
    self.Performer:setAnimation("gangs", shakeType, time, true, false, false, false)
    self.TargetPlayer:setAnimation("gangs", shakeType, time, true, false, false, false)

    if DEBUG then
        outputConsole("HandShake:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function HandShake:GetDynamicString()
    return 'return HandShake{}'
end