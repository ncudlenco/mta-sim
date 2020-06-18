StoryEpisodeBase = class(function(o, storyTimeOfDay, storyWeather, startingLocation)
    o.StoryTimeOfDay = storyTimeOfDay
    o.StoryWeather = storyWeather
    o.StartingLocation = startingLocation
    o.ValidStartingLocations = {}
    o.Objects = {}
end)

function StoryEpisodeBase:Initialize(...)
end

function StoryEpisodeBase:Play(...)
end