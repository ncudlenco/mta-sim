DynamicEpisode = class(StoryEpisodeBase, function(o, name)
    StoryEpisodeBase.init(o, nil, nil, nil)
    
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
    --Delete objects
    for i,v in ipairs(self.ObjectsToDelete) do
        removeWorldModel(v.modelid, v.size, v.position.x, v.position.y, v.position.z)
    end
    --Create objects
    for i,v in ipairs(self.Objects) do
        v:Create()
    end
end

function DynamicEpisode:Play(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end
    if player == nil then
        return false
    end

    if self.StartingLocation == nil then
        self.StartingLocation = PickRandom(self.POI)
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
    if unloadPathGraph then
        unloadPathGraph()
    end
    if DEBUG then
        outputConsole(self.name..":Destroyed")
    end
end

function DynamicEpisode:LoadFromFile()
    file = fileOpen("files/episodes/"..self.name..".json") 
    if file then
        local jsonStr = fileRead(file, fileGetSize(file))
        local episode = fromJSON(jsonStr)
        fileClose(file)

        self.InteriorId = episode.InteriorId
        self.graphPath = episode.graphPath
        self.name = episode.name
        if (episode.StoryTimeOfDay) then --TODO: set random if required
            self.StoryTimeOfDay = TimeOfDay(episode.StoryTimeOfDay.hour, episode.StoryTimeOfDay.minute)
        end
        if (episode.StoryWeather) then --TODO: set random if required
            self.StoryWeather = Weather(episode.StoryWeather.id, episode.StoryWeather.description)
        end

        for k,v in pairs(episode.Objects) do
            local obj = SampStoryObjectBase(v)
            table.insert(self.Objects, obj)
        end

        for k,v in pairs(episode.ObjectsToDelete) do
            local obj = SampStoryObjectBase(v)
            table.insert(self.ObjectsToDelete, obj)
        end

        for k,v in pairs(episode.POI) do
            local obj = Location(v.X, v.Y, v.Z, v.Angle, v.Interior, v.Description)
            for kk,vv in pairs(v.PossibleActions) do
                table.insert(obj.PossibleActions, DynamicAction(vv))
            end
            table.insert(self.POI, obj)
        end
        return true
    else 
        return false
    end
end