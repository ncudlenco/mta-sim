EmptyAction = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, params)
end)

function EmptyAction:Apply()
    if DEBUG then
        outputConsole("EmptyAction:Apply")
    end
    setPedAnimation(self.Performer)
end

function EmptyAction:GetDynamicString()
    return 'return EmptyAction{}'
end