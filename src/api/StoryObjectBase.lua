StoryObjectBase = class(IStoryItem, function(o, description)
    IStoryItem.init(o, description, eStoryItemType.Object)
    o.ObjectId = Guid().Id
end)

function StoryObjectBase:Create(...)
end

function StoryObjectBase:Destroy(...)
end

function StoryObjectBase:__tostring()
    return self.Description
end

function StoryObjectBase:__eq(other)
    return other and other:is_a(StoryObjectBase) and self.ObjectId == other.ObjectId
end