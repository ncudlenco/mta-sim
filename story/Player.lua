addEventHandler("onPlayerJoin", getRootElement(),
function (prevA, curA)
    source:fadeCamera (false)
    source:setHudComponentVisible("all", false)
    --Set a player specific id to be able to differentiate between players the logged data
    local g = Guid()
    source:setData("id", g.Id)
    Story(source, MAX_ACTIONS, LOG_DATA)

    if DEBUG then
        outputConsole("New player joined the server. Id ".. source:getData('id') .. " story id " .. source:getData('storyId'))
    end

    Timer(function(playerId, storyId)
        local story = STORIES[playerId][storyId]
        story:Play()
    end, 1000, 1, source:getData('id'), source:getData('storyId'))
end
)

addEventHandler("onPlayerSpawn", getRootElement(),
function (prevA, curA)
    if DEBUG then
        outputConsole("Player spawned ")
    end
    if STORIES and STORIES[source:getData('id')]  then
        local story = STORIES[source:getData("id")][source:getData('storyId')]
        if DEBUG then
            outputConsole("Found story for the spawned player. Picking a random action ")
        end
        if story and not FREE_ROAM then
            Timer(function()
                PickRandom(story.CurrentEpisode.StartingLocation.PossibleActions):Apply();
            end, 5000, 1)
        end
    end
end
)

addEventHandler( "onPlayerScreenShot", root,
function ( theResource, status, pixels, timestamp, tag )
    local playerId = tag:sub(0, 36)
    local storyId = tag:sub(37, 72)
    local playerName = tag:sub(73)
    local story = STORIES[playerId][storyId]

    if not SCREENSHOTS[playerId] then
        SCREENSHOTS[playerId] = {}
    end
    if not SCREENSHOTS[playerId][storyId] then
        SCREENSHOTS[playerId][storyId] = 0
    end
    SCREENSHOTS[playerId][storyId] = 1 + SCREENSHOTS[playerId][storyId]
    local elapsedMillis = SCREENSHOTS[playerId][storyId] * LOG_FREQUENCY
    local hours = string.format("%02.f", math.floor(elapsedMillis/3600000));
    local mins = string.format("%02.f", math.floor(elapsedMillis/60000 - (hours*60)));
    local secs = string.format("%02.f", math.floor(elapsedMillis/1000 - hours*3600 - mins *60));
    local millisecs = string.format("%03.f", math.floor(elapsedMillis - secs * 1000 - hours*3600000 - mins *60000));

    if status == "ok" then
        local newFile = File('data/'..playerId..'/'..storyId..'/'.. hours..'-'..mins..'-'..secs..'.'..millisecs..'-'..playerName..'.jpg')
        if (newFile) then
            newFile:write(pixels)
            newFile:close()
        end
    end    
end
)

function GetStory(player)
    if player == nil then
        if DEBUG then
            outputConsole("GetStory: player is null. ")
        end
        return nil
    end
    local storyId = player:getData('storyId')
    local playerId = player:getData('id')
    if storyId == nil or playerId == nil then
        if DEBUG then
            outputConsole("GetStory: storyId or playerId is null. ")
        end
        return nil
    end
    return STORIES[playerId][storyId]
end