TalkPhone = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" talks ", " starts talking "})
    StoryActionBase.init(o,params)
end)

function TalkPhone:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    math.randomseed(os.time())
    time = math.random(5000, 12000)

    -- I didn't see how you can iteract with other phones, only mobile ones, so I assume there is no need for an object specific description.
    story.Logger:Log(self.Description, self, false, true, {"finishes", "finishes talking"})
    self.Performer:setAnimation("PED", "PHONE_TALK", time, true, true, false, true)

    if DEBUG then
        outputConsole("TalkPhone:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TalkPhone:GetDynamicString()
    return 'return TalkPhone{}'
end