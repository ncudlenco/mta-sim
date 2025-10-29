StoryBase = class(function(o, spectators, maxActions, eventBus)
    o.Spectators = spectators
    o.MaxActions = maxActions
    o.Id = Guid().Id
    o.Episodes = {}
    o.StartTime = 0
    o.Loggers = {}
    o.History = {}
    o.PausedActions = {}
    o.EventBus = eventBus or EventBus:getInstance()
    o.CameraHandler = CameraHandler()
    o.ActionsOrchestrator = ActionsOrchestrator()
    o.SpatialCoordinator = SpatialCoordinator()
end)

function StoryBase:Play()
end