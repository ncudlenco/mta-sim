EndStory = class(StoryActionBase, function(o, player)
    local params = {}
    params.performer = player
    StoryActionBase.init(o, params)
    o.IsClosingAction = true
end)

function EndStory:Apply()
    if DEBUG then
        outputConsole("EndStory:Apply")
    end
    self.Performer:setAnimation()

    Timer(function(self)
        local story = GetStory(self.Performer)
        story:End()
        PedHandler:Dispose(self.Performer)
        if not story.LogData and not story.RecorderTimer then
            for _,spectator in ipairs(story.Spectators) do
                terminatePlayer(spectator, "story ended - end story call")
            end
        end
    end, 5000, 1, self)
end

function EndStory:GetDynamicString()
    return 'return EndStory{}'
end