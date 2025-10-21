StoryWeatherBase = class(IStoryItem, function(o, description)
    IStoryItem.init(o, description, eStoryItemType.Weather)
end)

function StoryWeatherBase:Apply(...)
end