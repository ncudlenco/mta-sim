Hug = class(StoryActionBase, function(o, params)
    params.description = " hug each other "
    params.name = 'Hug'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
end)

function Hug:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    local time = 2400
    story.Logger:Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

    self.Performer:setAnimation("gangs", "hndshkfa_swt", time, true, false, false, false)

    if DEBUG then
        outputConsole("Hug:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Hug:GetDynamicString()
    return 'return Hug{}'
end