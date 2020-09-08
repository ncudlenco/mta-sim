TalkPhone = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " talks ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function TalkPhone:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    math.randomseed(os.time())
    time = math.random(5000, 12000)

    -- I didn't see how you can iteract with other phones, only mobile ones, so I assume there is no need for an object specific description.
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation("PED", "PHONE_TALK", time, true, true, false, true)

    if DEBUG then
        outputConsole("TalkPhone:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TalkPhone:GetDynamicString()
    return 'return TalkPhone{}'
end