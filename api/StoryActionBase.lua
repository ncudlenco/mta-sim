StoryActionBase = class(IStoryItem, function(o, description, performer, targetItem, nextLocation, prerequisites, closingAction, nextAction)
    IStoryItem.init(o, description, eStoryItemType.Action)
    o.Performer = performer
    o.TargetItem = targetItem
    o.NextLocation = nextLocation
    o.Prerequisites = prerequisites
    o.ClosingAction = closingAction
    o.NextAction = nextAction
    o.ActionId = Guid().Id
end)

function StoryActionBase:__tostring()
    return self.Description
  end

function StoryActionBase:__eq(other)
    return other and other:is_a(StoryActionBase) and self.ActionId == other.ActionId
end

function StoryActionBase:Apply(...)
end