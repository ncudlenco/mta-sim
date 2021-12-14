function initializePlayer(source)
    source:fadeCamera (false)
    source:setHudComponentVisible("all", false)
    --Set a player specific id to be able to differentiate between players the logged data
    local g = Guid()
    source:setData("id", g.Id)
    source:setData("isPed", false)
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    
    SCREENSHOTS = {}
    CURRENT_STORY = nil
    GRAPH = {}
    source:setData('takenShots', 0)
    if LOAD_FROM_GRAPH and #INPUT_GRAPHS > 0 then
        LOAD_FROM_GRAPH = INPUT_GRAPHS[1]
    end
    if not FREE_ROAM and LOAD_FROM_GRAPH then
        CURRENT_STORY = GraphStory(source, LOG_DATA)
    else
        CURRENT_STORY = Story(source, MAX_ACTIONS, LOG_DATA)
    end
    if DEBUG then
        outputConsole("New player joined the server. Id ".. source:getData('id') .. " story id " .. source:getData('storyId'))
    end
--TODO: add parameters for actionbase:
-- TopologicalOrder; stats consumed; stats rewarded; 
--implement server side episode json with points of interest and in each point of interest define possible action
    --Set the player's needs
    --basic needs -> physiological needs
    --health, hunger, thirst, rest
    --psychological needs -> belongingness and love needs
    --socializing --talking with friends, going to a restaurant with them
    --love --going to a date, kissing, giving gifts, hugging, walking while holding hands
    --fun --watching TV, going 
    --psychological needs -> esteem needs
    --money --prestige, accomplishment
    --prestige --having low body fat, high body muscle and stamina, lung capacity, having an expensive car, expensive clothes, expensive house
    --self-fulfillment -> achieving one's full potential, including creative activities
    -- if DEBUG then
    --     outputConsole("Initializing player needs...")
    -- end
    -- for i, a in pairs(NEEDS) do
    --     if a then 
    --         a:setRandomForPlayer(source)
    --     end
    -- end
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    local chance = math.random(0, 1)
    if chance < 0.5 then
        source:setData('inventory_1', 'phone')
        source:setData('inventory', '1')
    end
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    chance = math.random(0, 1)
    if chance < 0.5 then
        source:setData('inventory_2', 'cigarette')
        source:setData('inventory', '2')
    end
    Timer(function(playerId, storyId)
        CURRENT_STORY:Play()
    end, 2000, 1, source:getData('id'), source:getData('storyId'))
end

addEventHandler("onPlayerJoin", getRootElement(),
function (prevA, curA)
    initializePlayer(source)
end
)

addEventHandler("onPlayerSpawn", getRootElement(),
function (prevA, curA)
    if DEBUG then
        outputConsole("Player spawned ")
    end
    if CURRENT_STORY  then
        local story = CURRENT_STORY
        if DEBUG then
            outputConsole("Found story for the spawned player. Picking a random action ")
        end
        if story and not FREE_ROAM then
            Timer(function()
                local firstAction = story.CurrentEpisode.StartingLocation:GetNextValidAction(story.Actor)
                if firstAction then
                    firstAction:Apply()
                else
                    if DEBUG then
                        print("No valid action found, the player is waiting "..story.Actor:getData('id'))
                    end
                end
                for _,ped in ipairs(story.CurrentEpisode.peds) do
                    local idx = ped:getData('startingPoiIdx')
                    if DEBUG then
                        print("Starting poi idx for ped "..idx)
                    end
                    if idx > 0 then
                        local firstAction = story.CurrentEpisode.POI[idx]:GetNextValidAction(ped)
                        if firstAction then
                            firstAction:Apply()
                        else
                            if DEBUG then
                                print("No valid action found, the ped is waiting "..ped:getData('id'))
                            end
                        end
                    end
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
            outputConsole("Found story for the player that quit. Trying to clear the objects")
        end
        if story and story.CurrentEpisode then
            Timer(function()
                if not story.CurrentEpisode.Disposed then
                    story.CurrentEpisode:Destroy()
                end
            end, 5000, 1)
        end
    end
    SCREENSHOTS = {}
    CURRENT_STORY = nil
    GRAPH = {}
    player:setData('takenShots', 0)

    Timer(function()
        if #INPUT_GRAPHS > 0 then
            table.remove(INPUT_GRAPHS, 1)
            if #INPUT_GRAPHS > 0 then
                initializePlayer(player)
            else
                player:kick(reason)
            end
        else
            player:kick(reason)
        end
    end, 10000,1)
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
        local newFile = File(LOAD_FROM_GRAPH..'_out/'..storyId..'/'
        --  ..playerId..'/'
            .. hours..'-'..mins..'-'..secs..'.'..millisecs..'-'..playerName..'.jpg')
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
    return CURRENT_STORY
end