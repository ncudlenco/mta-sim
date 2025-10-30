
function startSimulation(source)
    print("Starting simulation")

    CURRENT_STORY = nil
    if LOAD_FROM_GRAPH and #INPUT_GRAPHS > 0 then
        LOAD_FROM_GRAPH = INPUT_GRAPHS[1]
    end

    -- Create EventBus first (singleton, created once)
    local eventBus = EventBus:getInstance()

    -- Create MTA-specific adapter provider
    local adapterProvider = MTAAdapterProvider()
    -- Extract game-agnostic spectator data from MTA elements
    local spectatorsData = adapterProvider:extractSpectatorData(SPECTATORS)

    -- Create artifact collection factory and manager
    local artifactCollectionFactory = ArtifactCollectionFactory(nil, adapterProvider)
    local artifactManager = artifactCollectionFactory:createManager()

    -- Setup event subscriptions BEFORE creating story
    if artifactManager then
        artifactCollectionFactory:setupEventSubscriptions(artifactManager, eventBus)
        -- Register all collectors (raw, segmentation, depth) using game-agnostic data
        artifactCollectionFactory:registerCollectors(artifactManager, spectatorsData)
    end

    -- Create story with EventBus injected
    if not FREE_ROAM and LOAD_FROM_GRAPH then
        CURRENT_STORY = GraphStory(SPECTATORS, LOG_DATA, artifactCollectionFactory, artifactManager, eventBus)
    else
        CURRENT_STORY = RandomStory(SPECTATORS, MAX_ACTIONS, LOG_DATA, artifactCollectionFactory, artifactManager, eventBus)
    end

    -- Update artifact manager with story ID after story is instantiated
    if artifactManager and CURRENT_STORY and CURRENT_STORY.Id then
        artifactManager:updateConfig({storyId = CURRENT_STORY.Id})
    end

        -- Handle EXPORT_MODE: export game capabilities and exit
    if EXPORT_MODE then
        print("=== EXPORT MODE ACTIVE ===")
        print("Exporting game capabilities to JSON...")

        -- Run exporter
        local exporter = GameWorldExporter()
        exporter:ExportCapabilities()

        print("=== Export Complete ===")
        print("Shutting down server...")

        -- Shutdown server after export
        Timer(function()
            shutdown()
        end, 2000, 1)

        return
    else
        Timer(function()
            CURRENT_STORY:Play()
        end, 2000, 1)
    end

end

--- Check if all spectators are both joined and have finished downloading resources
-- @return boolean True if all expected spectators are ready
function checkAllSpectatorsReady()
    if #SPECTATORS ~= EXPECTED_SPECTATORS then
        return false
    end

    for _, spectator in ipairs(SPECTATORS) do
        if not spectator:getData('clientReady') then
            return false
        end
    end

    return true
end

--- Handle client ready signal from a spectator
-- Called when client has finished downloading all resource files
-- @param player The player element that is ready
function onClientReadySignal()
    local player = source
    processClientReady(player)
end

function processClientReady(player)
    player:setData('clientReady', true)
    if DEBUG then
        outputConsole("Player "..player:getData('id').." signaled client ready ")
    end

    if checkAllSpectatorsReady() then
        if DEBUG then
            outputConsole("All spectators are ready. Starting simulation ")
        end
        startSimulation()
    end
end

function initializeCameraMan(cameraMan, triggerClientReady)
    if not DEFINING_EPISODES then
        cameraMan:fadeCamera (false)
    end
    cameraMan:setHudComponentVisible("all", false)
    showChat(cameraMan, false)

    --Set a player specific id to be able to differentiate between players the logged data
    cameraMan:setData("isPed", false)
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    cameraMan:setData('fadedCamera', false)
    cameraMan:setData('spawned', false)
    cameraMan:setData('clientReady', false)  -- Initialize as not ready

    table.insert(SPECTATORS, cameraMan)
    cameraMan:setData("id", "spectator"..#SPECTATORS)

    if DEBUG then
        outputConsole("New player joined the server. Id " .. cameraMan:getData('id') .. " (waiting for client to download resources)")
    end

    -- Note: Simulation will start when all spectators signal clientReady
    -- This is handled in onClientReadySignal() instead
    if triggerClientReady then
        processClientReady(cameraMan)
    end
end

addEventHandler("onPlayerJoin", getRootElement(), function (prevA, curA) initializeCameraMan(source) end)

-- Register event handler for client ready signal
addEvent("onClientFullyReady", true)
addEventHandler("onClientFullyReady", getRootElement(), onClientReadySignal)

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
                        initializeCameraMan(player, true)
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
    -- If the simulation was still running, emit an error
    if CURRENT_STORY and not CURRENT_STORY.Disposed then
        error("The client disconnected from the server during the simulation leaving it in an error state. The simulation will be terminated.")
    end
    if DEBUG then
        outputConsole(getPlayerName(source).. " has left the server (" .. quitType .. ")")
    end
end )


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