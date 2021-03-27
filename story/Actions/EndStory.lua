EndStory = class(StoryActionBase, function(o, player)
    params.performer = player
    StoryActionBase.init(o, params)
end)

function EndStory:Apply()
    if DEBUG then
        outputConsole("EndStory:Apply")
    end
    local story = GetStory(self.Performer)
    story:End()
    if not story.LogData and not story.RecorderTimer then
        story.Actor:kick("story ended - end story call")
    end
end

function EndStory:GetDynamicString()
    return 'return EndStory{}'
end