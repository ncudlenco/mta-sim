PunchDesk = class(StoryActionBase, function(o, params)
    params.description = " punches the desk "
    params.name = 'PunchDesk'

    StoryActionBase.init(o,params)
end)

function PunchDesk:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Crash", -1, false, true, false, true)

    if DEBUG then
        outputConsole("PunchDesk:Apply")
    end

    OnGlobalActionFinished(5000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function PunchDesk:GetDynamicString()
    return 'return PunchDesk{}'
end