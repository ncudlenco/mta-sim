StoryLocationBase = class(IStoryItem, function(o, description, possibleActions)
    IStoryItem.init(o, description, eStoryItemType.Location)
    o.PossibleActions = possibleActions
end
)