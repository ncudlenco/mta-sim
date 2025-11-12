--- Client-side camera control for cinematic mode
--- Handles MTA's built-in camera following using client-side setCameraTarget
--- @module CameraControlClient

--- Start following an actor with MTA's built-in camera
--- First positions camera behind actor, then starts smooth following
--- Uses cinematic camera view mode for professional-looking shots
--- @param data table Contains: actor (element), initialPos (Vector3), initialLookAt (Vector3)
addEvent("sv2l:startCameraFollow", true)
addEventHandler("sv2l:startCameraFollow", root, function(data)
    local actor = data.actor
    local initialPos = data.initialPos
    local initialLookAt = data.initialLookAt

    if not actor or not isElement(actor) then
        outputDebugString("[CameraControlClient] Error: Invalid actor element for camera follow", 1)
        return
    end

    -- Step 1: Position camera behind actor for clean start
    if initialPos and initialLookAt then
        setCameraMatrix(
            initialPos.x, initialPos.y, initialPos.z,
            initialLookAt.x, initialLookAt.y, initialLookAt.z
        )

        outputDebugString(string.format("[CameraControlClient] Set initial camera position behind actor at (%.2f, %.2f, %.2f)",
            initialPos.x, initialPos.y, initialPos.z))
    end

    -- Step 2: Set camera view mode to cinematic
    -- Vehicle mode 5 = Cinematic, Ped mode 3 = Far (best for cinematic shots)
    setCameraViewMode(5, 3)

    -- Step 3: Start following actor (MTA smoothly interpolates from initial position)
    setCameraTarget(actor)

    outputDebugString("[CameraControlClient] Started cinematic camera following actor: " .. tostring(getElementType(actor)))
end)

--- Stop following and reset camera to player
addEvent("sv2l:stopCameraFollow", true)
addEventHandler("sv2l:stopCameraFollow", root, function()
    -- Reset camera to local player
    setCameraTarget(localPlayer)

    outputDebugString("[CameraControlClient] Stopped camera follow, reset to player")
end)

--- Set camera to specific matrix position (for static/closeup shots)
--- @param posX number Camera X position
--- @param posY number Camera Y position
--- @param posZ number Camera Z position
--- @param lookX number Look-at X position
--- @param lookY number Look-at Y position
--- @param lookZ number Look-at Z position
addEvent("sv2l:setCameraMatrix", true)
addEventHandler("sv2l:setCameraMatrix", root, function(posX, posY, posZ, lookX, lookY, lookZ)
    setCameraMatrix(posX, posY, posZ, lookX, lookY, lookZ)

    outputDebugString(string.format("[CameraControlClient] Set camera matrix: pos(%.2f, %.2f, %.2f) lookAt(%.2f, %.2f, %.2f)",
        posX, posY, posZ, lookX, lookY, lookZ))
end)
