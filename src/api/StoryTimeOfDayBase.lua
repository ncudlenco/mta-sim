StoryTimeOfDayBase = class(IStoryItem, function(o, description)
    IStoryItem.init(o, description, eStoryItemType.TimeOfDay)
end)

function StoryTimeOfDayBase:Apply(...)
end