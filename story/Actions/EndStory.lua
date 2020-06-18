EndStory = class(StoryActionBase, function(o, player)
    StoryActionBase.init(o, "", player, nil, nil, {}, nil, nil)
end)

function EndStory:Apply()
    if DEBUG then
        outputConsole("EndStory:Apply")
    end
    local story = GetStory(self.Performer)
    story:End()
end