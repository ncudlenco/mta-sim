StoryBase = class(function(o, spectators, maxActions)
    o.Spectators = spectators
    o.MaxActions = maxActions
    o.Id = Guid().Id
    o.Episodes = {}
    o.StartTime = 0
    o.Loggers = {}
    o.History = {}
end)

function StoryBase:Play()
end