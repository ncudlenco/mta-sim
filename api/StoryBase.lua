StoryBase = class(function(o, spectators, maxActions)
    o.Spectators = spectators
    o.MaxActions = maxActions
    o.Id = Guid().Id
    o.Episodes = {}
    o.StartTime = 0
    o.Loggers = {}
    o.History = {}
    o.PausedActions = {}
    o.CameraHandler = CameraHandler()
end)

function StoryBase:Play()
end