function callClientFunction(funcname, ...)
    local arg = { ... }
    if (arg[1]) then
        for key, value in next, arg do arg[key] = tonumber(value) or value end
    end
    loadstring("return "..funcname)()(unpack(arg))
end

function onDisablePedCollisions(var)
    print("onDisablePedCollisions")
    outputConsole("onDisablePedCollisions")
    for i,v in pairs(getElementsByType("ped")) do --LOOP through all peds
        setElementCollidableWith(v, localPlayer, false) -- Set the collison off with the other peds.
    end
    -- for i,v in pairs(getElementsByType("player")) do --LOOP through all players
    --     setElementCollidableWith(v, localPlayer, false) -- Set the collison off with the other players.
    -- end
end

--- Disable collisions between a specific ped and all other peds
-- Called when a ped sits down to prevent bumping animations
-- @param ped The ped element to disable collisions for
function onDisablePedToPedCollisions(ped)
    if not ped or not isElement(ped) then
        return
    end

    if DEBUG then
        print("onDisablePedToPedCollisions - Disabling collisions for ped")
        outputConsole("onDisablePedToPedCollisions - Disabling collisions for ped")
    end

    for _,v in pairs(getElementsByType("ped")) do
        if v ~= ped then
            setElementCollidableWith(ped, v, false)
        end
    end
end

--- Re-enable collisions between a specific ped and all other peds
-- Called when a ped stands up or gets off furniture
-- @param ped The ped element to re-enable collisions for
function onEnablePedToPedCollisions(ped)
    if not ped or not isElement(ped) then
        return
    end

    if DEBUG then
        print("onEnablePedToPedCollisions - Enabling collisions for ped")
        outputConsole("onEnablePedToPedCollisions - Enabling collisions for ped")
    end

    for _,v in pairs(getElementsByType("ped")) do
        if v ~= ped then
            setElementCollidableWith(ped, v, true)
        end
    end
end

function initHandlers()
    addEvent("onServerCallsClientFunction", true)
    addEventHandler("onServerCallsClientFunction", resourceRoot, callClientFunction)
end

--- Signal to server that client has finished downloading all resource files and is ready
-- This is triggered after all .dff, .txd, and script files are downloaded
function onClientResourceReady()
    outputConsole("[Client] All resource files downloaded, signaling server that client is ready")
    triggerServerEvent("onClientFullyReady", localPlayer)
end

addEvent("onDisablePedCollisions", true)
addEventHandler("onDisablePedCollisions", root, onDisablePedCollisions)
addEvent("onDisablePedToPedCollisions", true)
addEventHandler("onDisablePedToPedCollisions", root, onDisablePedToPedCollisions)
addEvent("onEnablePedToPedCollisions", true)
addEventHandler("onEnablePedToPedCollisions", root, onEnablePedToPedCollisions)
addEventHandler("onClientResourceStart", resourceRoot, initHandlers)
addEventHandler("onClientResourceStart", resourceRoot, onClientResourceReady)
--todo: disable collisions for spectators with peds https://forum.mtasa.com/topic/123001-new-help-how-to-disable-players-collision/