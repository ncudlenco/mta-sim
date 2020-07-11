StoryLocationBase = class(IStoryItem, function(o, description, possibleActions)
    IStoryItem.init(o, description, eStoryItemType.Location)
    o.PossibleActions = possibleActions
    o.LocationId = Guid().Id
end
)

function StoryLocationBase:__tostring()
    return self.Description
  end

function StoryLocationBase:__eq(other)
    return other and other:is_a(StoryLocationBase) and self.LocationId == other.LocationId
end