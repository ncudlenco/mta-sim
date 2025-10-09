
function startSimulation(source)
    print("Starting simulation")
    SCREENSHOTS = {}
    CURRENT_STORY = nil
    if LOAD_FROM_GRAPH and #INPUT_GRAPHS > 0 then
        LOAD_FROM_GRAPH = INPUT_GRAPHS[1]
    end
    if not FREE_ROAM and LOAD_FROM_GRAPH then
        CURRENT_STORY = GraphStory(SPECTATORS, LOG_DATA)
    else
        CURRENT_STORY = Story(SPECTATORS, MAX_ACTIONS, LOG_DATA)
    end

    Timer(function()
        CURRENT_STORY:Play()
    end, 2000, 1)
end

function initializeSpectator(source)
    if not DEFINING_EPISODES then
        source:fadeCamera (false)
    end
    source:setHudComponentVisible("all", false)

    --Set a player specific id to be able to differentiate between players the logged data
    source:setData("isPed", false)
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    source:setData('takenShots', 0)
    source:setData('fadedCamera', false)
    source:setData('spawned', false)


    table.insert(SPECTATORS, source)
    source:setData("id", "spectator"..#SPECTATORS)

    if DEBUG then
        outputConsole("New player joined the server. Id ".. source:getData('id'))
    end

    if #SPECTATORS == EXPECTED_SPECTATORS then
        if not DEFINING_EPISODES then
            startSimulation(source)
        end
    end
end

addEventHandler("onPlayerJoin", getRootElement(), function (prevA, curA) initializeSpectator(source) end)

addEventHandler("onPlayerSpawn", getRootElement(),
function (prevA, curA)
    if DEFINING_EPISODES then
        return
    end
    if DEBUG and source:getData('id') then
        outputConsole("Player "..source:getData('id').."spawned ")
    end
    source:setData('spawned', true)
    if CURRENT_STORY and All(SPECTATORS, function(spectator) return spectator:getData('spawned') end) then
        local story = CURRENT_STORY
        if DEBUG then
            outputConsole("Found story for the spawned player. Picking a random action ")
        end
        if story and not FREE_ROAM then
            Timer(function()
                for i,ped in ipairs(story.CurrentEpisode.peds) do
                    OnGlobalActionFinished(0, ped:getData('id'), ped:getData('storyId'))
                end
            end, 5000, 1)
        end
    end
end
)

function terminatePlayer(player, reason)
    player:fadeCamera (false)
    if CURRENT_STORY then
        local story = CURRENT_STORY
        if DEBUG then
            outputConsole("Cleaning the objects of the CURRENT_STORY")
        end
        if story and story.CurrentEpisode then
            Timer(function()
                if not story.CurrentEpisode.Disposed then
                    story.CurrentEpisode:Destroy()
                end
            end, 5000, 1)
        end
    end
    SCREENSHOTS[player:getData('id')] = {}
    player:setData('takenShots', 0)
    local playerIdx = LastIndexOf(SPECTATORS, player, function(item, player) return item:getData('id') == player:getData('id') end)
    table.remove(SPECTATORS, playerIdx)

    if #SPECTATORS == 0 then
        -- Stop all previously existing timers
        for _, timer in ipairs(getTimers()) do
            timer:destroy()
        end

        Timer(function()
            for i,spectator in ipairs(getElementsByType("player")) do
                if #INPUT_GRAPHS > 0 then
                    table.remove(INPUT_GRAPHS, 1)
                    if #INPUT_GRAPHS > 0 then
                        initializeSpectator(player)
                    else
                        player:kick(reason)
                    end
                else
                    player:kick(reason)
                end
            end
        end, 10000,1)
    end
end

addEventHandler ( "onPlayerQuit", root,
function ( quitType )
    if DEBUG then
        outputConsole(getPlayerName(source).. " has left the server (" .. quitType .. ")")
    end
end )

addEventHandler( "onPlayerScreenShot", root,
function ( theResource, status, pixels, timestamp, tag )
    local split = tag:split(';')
    local playerId = split[1]
    local storyId = split[2]
    local playerName = split[3]
    local story = CURRENT_STORY

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
        local rootFolder = 'data_out'
        if type(LOAD_FROM_GRAPH) == "string" then
            rootFolder = LOAD_FROM_GRAPH..'_out'
        end
        local newFile = File(rootFolder..'/'..storyId..'/'
         ..playerId..'/'
            .. hours..'-'..mins..'-'..secs..'.'..millisecs..'-'..playerName..'.jpg')
        if (newFile) then
            newFile:write(pixels)
            newFile:close()
        end
        --TODO: add status error and create a new file which signals a forced quit
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
    return CURRENT_STORY
end