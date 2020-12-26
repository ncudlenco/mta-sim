DynamicEpisode = class(StoryEpisodeBase, function(o, name)
    StoryEpisodeBase.init(o, {name = name})
    
    o.InteriorId = nil
    o.graphPath = nil
    o.ObjectsToDelete = {}
    o.POI = {}
    o.name = name or ""
end)


function DynamicEpisode:Initialize(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    --Link the POI with move actions between them
    if self.graphId then
        for i,p1 in ipairs(self.POI) do
            table.insert(self.ValidStartingLocations, p1)
            for j, p2 in ipairs(self.POI) do
                if i ~= j then
                    local prerequisites = {}
                    if #p1.PossibleActions > 0 then
                        prerequisites = {p1.PossibleActions[1]}
                    end
                    table.insert(p1.PossibleActions, Move{performer = player, targetItem = p2, nextLocation = p2, prerequisites = prerequisites, graphId = self.graphId})
                end
            end
        end
    end

    --Set the performer for all the actions
    for _,poi in ipairs(self.POI) do
        if poi.allActions then
            for _,a in ipairs(poi.allActions) do
                a.Performer = player
            end
        end
    end

    StoryEpisodeBase.Initialize(self, arg)
end

function DynamicEpisode:Play(...)
    StoryEpisodeBase.ProcessRegions(self)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    if self.StartingLocation == nil then
        self.StartingLocation = PickRandom(Where(self.ValidStartingLocations, function(x)
            return not x.isBusy
        end))
    end
    self.StartingLocation:SpawnPlayerHere(player)
    if DEBUG then
        outputConsole(self.name..":Play - picked random location "..self.StartingLocation.Description.." Spawn scheduled")
    end
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