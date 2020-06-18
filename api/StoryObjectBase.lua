StoryObjectBase = class(IStoryItem, function(o, description)
    IStoryItem.init(o, description, eStoryItemType.Object) 
end)

function StoryObjectBase:Create(...)
end

function StoryObjectBase:Destroy(...)
end