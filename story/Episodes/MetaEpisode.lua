MetaEpisode = class(StoryEpisodeBase, function(o, episodes)
    local name = join(';', Select(episodes, function(e) return e.name end))
    StoryEpisodeBase.init(o, {name = name})
    
    o.InteriorId = nil
    o.graphPath = nil
    for _,e in ipairs(episodes) do
        for _,poi in ipairs(e.POI) do
            poi.Episode = e
        end
        o.POI = concat(o.POI, e.POI)
        o.Objects = concat(o.Objects, e.Objects)
        o.Regions = concat(o.Regions, e.Regions)
        o.ObjectsToDelete = concat(o.ObjectsToDelete, e.ObjectsToDelete)
        o.peds = concat(o.peds, e.peds)
        o.supertemplates = concat(o.supertemplates, e.supertemplates)
    end
    o.Episodes = episodes
end)


function MetaEpisode:Initialize(actor, isTemporaryInitialize, actors, graphOfEvents)
    if(#self.Episodes == 0) then return end
    
    self.POI = {}
    self.Objects = {}
    self.Regions = {}
    self.peds = {}
    for i, e in ipairs(self.Episodes) do
        if i == 1 then
            e:Initialize(actor, isTemporaryInitialize, actors, graphOfEvents)
        else
            e:Initialize(actor, isTemporaryInitialize, {}, graphOfEvents)
        end
    end
    for _,e in ipairs(self.Episodes) do
        for _,poi in ipairs(e.POI) do
            poi.Episode = e
        end
        self.POI = concat(self.POI, e.POI)
        self.Objects = concat(self.Objects, e.Objects)
        self.Regions = concat(self.Regions, e.Regions)
        self.peds = concat(self.peds, e.peds)
    end
    -- Link with move actions the episodes
    local episodeLinks = Where(Select(self.POI, function(poi) if #poi.episodeLinks > 0 then
        local le = FirstOrDefault(self.Episodes, function(e) return Any(poi.episodeLinks, function(l) return l == e.name end) end)
        if le then return {e1 = poi.Episode, e2 = le} else return nil end
        else return nil end
    end), function(poi) return poi ~= nil end)
    for _,tuple in ipairs(episodeLinks) do
        for _,l1 in ipairs(tuple.e1.POI) do
            for _,l2 in ipairs(tuple.e2.POI) do
                local prerequisites = {}
                if #l1.PossibleActions > 0 then
                    prerequisites = {l1.PossibleActions[1]}
                end
                local moveAction = Move{performer = actor, targetItem = l2, nextLocation = l2, prerequisites = prerequisites, graphId = l1.Episode.graphId}
                table.insert(l1.PossibleActions, moveAction)
                table.insert(l1.allActions, moveAction)
                if DEBUG_CHAIN_LINKED_ACTIONS then
                    print('Move action from '..l1.Description..' to '..l2.Description)
                end
            end
        end
    end
    self.initialized = true
end

function MetaEpisode:Destroy()
    for _,e in ipairs(self.Episodes) do
        e:Destroy()
    end
    self.Disposed = true
end

function MetaEpisode:Play(...)
    StoryEpisodeBase.Play(self, unpack(arg))
end