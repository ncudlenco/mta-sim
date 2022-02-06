LookAtTheWatch = class(StoryActionBase, function(o, params)
    params.description = " looks at the handwatch "
    params.name = 'LookAtTheWatch'

    StoryActionBase.init(o,params)
end)

function LookAtTheWatch:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    StoryActionBase.GetLogger(self, story):Log(self.Description, self)
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Watch", -1, false, true, false, true)

    if DEBUG then
        outputConsole("LookAtTheWatch:Apply")
    end

    OnGlobalActionFinished(2000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function LookAtTheWatch:GetDynamicString()
    return 'return LookAtTheWatch{}'
end