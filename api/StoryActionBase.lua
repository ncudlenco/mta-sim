StoryActionBase = class(IStoryItem, function(o, params)
    IStoryItem.init(o, params.description or params.Description or '', eStoryItemType.Action)
    o.Performer = params.performer or params.Performer or nil
    o.TargetItem = params.targetItem or params.TargetItem or nil
    o.NextLocation = params.nextLocation or params.NextLocation or nil
    o.Prerequisites = params.prerequisites or params.Prerequisites or {}
    o.ClosingAction = params.closingAction or params.ClosingAction or nil
    o.NextAction = params.nextAction or params.NextAction or nil
    math.randomseed(os.time())
    math.random(); math.random(); math.random()
    math.randomseed(os.time())
    math.random(); math.random(); math.random()

    o.ActionId = Guid().Id
    o.TopologicalOrder = params.topologicalOrder or params.TopologicalOrder or -1
    o.Penalties = params.penalties or params.Penalties or {}
    o.Rewards = params.rewards or params.Rewards or {}
    o.IsClosingAction = params.isClosingAction or params.IsClosingAction or false
    o.Buffer = {}
    o.Name = params.name or ''
end)

function StoryActionBase:__tostring()
    return self.Description
  end

function StoryActionBase:__eq(other)
    return other and other:is_a(StoryActionBase) and self.ActionId == other.ActionId
end

function StoryActionBase:Apply(...)
end