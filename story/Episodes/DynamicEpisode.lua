DynamicEpisode = class(StoryEpisodeBase, function(o, name)
    StoryEpisodeBase.init(o, {name = name})
    
    o.InteriorId = nil
    o.graphPath = nil
    o.ObjectsToDelete = {}
    o.POI = {}
    o.name = name or ""
end)


function DynamicEpisode:Initialize(...)
    StoryEpisodeBase.Initialize(self, unpack(arg))
end

function DynamicEpisode:Destroy()
    for _,item in ipairs(self.Objects) do
        item:Destroy()
    end
    if unloadPathGraph and self.graphId then
        unloadPathGraph(self.graphId)
    end
    if DEBUG then
        outputConsole(self.name..":Destroyed")
    end
    StoryEpisodeBase:Destroy()
end