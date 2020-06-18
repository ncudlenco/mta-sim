EmptyAction = class(StoryActionBase, function(o)
    StoryActionBase.init(o, nil, nil, nil, nil, nil, nil, nil)
end)

function EmptyAction:Apply()
    if DEBUG then
        outputConsole("EmptyAction:Apply")
    end
end