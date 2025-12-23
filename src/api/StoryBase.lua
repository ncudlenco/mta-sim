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
    o.ActionsOrchestrator = ActionsOrchestrator(o.EventBus)
    o.SpatialCoordinator = SpatialCoordinator()
    if o.ActionsOrchestrator and DEBUG then
        print("[GraphStory] Using pre-configured actions orchestrator")
    end
    o.ActionsOrchestrator:Initialize()
    o.PoiCoordinator = POICoordinator()
    o.PoiCoordinator:Initialize()
    if o.PoiCoordinator and DEBUG then
        print("[GraphStory] Using pre-configured POI coordinator")
    end

end)

function StoryBase:Play()
end