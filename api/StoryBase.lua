StoryBase = class(function(o, actor, maxActions)
    o.Actor = actor
    o.MaxActions = maxActions
    o.Id = Guid().Id
    o.Episodes = {}
    o.StartTime = 0
    o.Logger = nil
    o.History = {}
end)

function StoryBase:Play()
end