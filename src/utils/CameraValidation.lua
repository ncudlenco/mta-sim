--- Camera position validation and adjustment utilities (Server-Side)
--- Uses async client-side raycasting via events for validation
--- Pure event-driven architecture with callbacks
--- @module CameraValidation

CameraValidation = {}

--- Pending validation callbacks keyed by requestId
CameraValidation.pendingCallbacks = {}

--- Request ID counter
CameraValidation.requestCounter = 0

--- Generate unique request ID using simple counter
--- @return string Request ID
function CameraValidation.generateRequestId()
    CameraValidation.requestCounter = CameraValidation.requestCounter + 1
    return tostring(CameraValidation.requestCounter)
end

--- Convert region to 2D polygon vertices for client transmission
--- @param region Region Region object with vertices
--- @return table Array of {x, y} vertices
function CameraValidation.getRegionPolygon(region)
    if not region or not region.vertices then
        return nil
    end

    local polygon = {}
    for _, vertex in ipairs(region.vertices) do
        table.insert(polygon, {
            x = vertex.x or vertex[1],
            y = vertex.y or vertex[2]
        })
    end

    return polygon
end

--- Async camera position validation using client-side raycasting
--- Sends request to client, invokes callback when response received
--- @param cameraPos Vector3 Camera position to validate
--- @param subjectPos Vector3 Subject position (what camera should see)
--- @param region Region Region the camera should be in (nil-safe)
--- @param params table Camera parameters {distance, offset, height, fov}
--- @param options table Validation options {checkLineOfSight, checkRegionBounds, strategy, maxAttempts}
--- @param callback function Callback(result) invoked when validation completes
function CameraValidation.validateCameraPositionAsync(cameraPos, subjectPos, region, params, options, callback)
    -- Skip validation if globally disabled
    if not ENABLE_CAMERA_VALIDATION then
        if callback then
            callback({
                isValid = true,
                finalCameraPos = nil,
                adjustmentMade = false,
                reasons = {}
            })
        end
        return
    end

    -- Skip validation if no region (can't check bounds or send polygon)
    if not region then
        if DEBUG_CAMERA_VALIDATION then
            print("[CameraValidation] No region provided, skipping validation")
        end
        if callback then
            callback({
                isValid = true,
                finalCameraPos = nil,
                adjustmentMade = false,
                reasons = {}
            })
        end
        return
    end

    -- Generate request ID
    local requestId = CameraValidation.generateRequestId()

    -- Store callback for this request
    if callback then
        CameraValidation.pendingCallbacks[requestId] = callback
    end

    -- Get region polygon for client
    local regionPolygon = CameraValidation.getRegionPolygon(region)

    -- Prepare request data
    local requestData = {
        requestId = requestId,
        idealCameraPos = {x = cameraPos.x, y = cameraPos.y, z = cameraPos.z},
        subjectPos = {x = subjectPos.x, y = subjectPos.y, z = subjectPos.z},
        regionPolygon = regionPolygon,
        params = params or {},
        options = options or {
            checkLineOfSight = true,
            checkRegionBounds = true,
            strategy = "incremental",
            maxAttempts = 10
        }
    }

    if DEBUG_CAMERA_VALIDATION then
        print("[CameraValidation] Sending validation request "..requestId.." to client")
    end

    -- Trigger client event for all spectators (they all need same camera position)
    for _, spectator in ipairs(CURRENT_STORY.Spectators) do
        triggerClientEvent(spectator, "sv2l:validateCameraPosition", spectator, requestData)
    end
end

--- Handle validation response from client
--- @param result table Result from client {requestId, isValid, finalCameraPos, adjustmentMade, reasons}
function CameraValidation.handleValidationResponse(result)
    if not result or not result.requestId then
        print("[CameraValidation] ERROR: Invalid validation response from client")
        return
    end

    if DEBUG_CAMERA_VALIDATION then
        print("[CameraValidation] Received validation response "..result.requestId..": "..(result.isValid and "valid" or "invalid"))
    end

    -- Look up pending callback
    local callback = CameraValidation.pendingCallbacks[result.requestId]
    if callback then
        -- Invoke callback with result
        callback(result)

        -- Remove from pending
        CameraValidation.pendingCallbacks[result.requestId] = nil
    else
        if DEBUG_CAMERA_VALIDATION then
            print("[CameraValidation] Warning: No callback found for request "..result.requestId)
        end
    end
end

--- Check if position is inside region polygon (server-side utility)
--- @param position Vector3 Position to check
--- @param region Region Region to check against
--- @return boolean True if inside region
function CameraValidation.isPositionInRegion(position, region)
    if not region then return true end
    return region:IsPointInside2(position)
end

--- Detect if actor has changed region since last check
--- @param actor table Actor ped
--- @param lastRegion Region Previous region (nil if first check)
--- @return boolean True if region changed
--- @return Region Current region
function CameraValidation.hasActorChangedRegion(actor, lastRegion)
    if not actor then return false, lastRegion end

    local currentRegionId = actor:getData('currentRegionId')

    if not lastRegion then
        -- First check, find current region
        local currentRegion = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r)
            return r.Id == currentRegionId
        end)
        return false, currentRegion
    end

    local changed = (lastRegion.Id ~= currentRegionId)

    if changed then
        local currentRegion = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r)
            return r.Id == currentRegionId
        end)
        return true, currentRegion
    end

    return false, lastRegion
end

--- Register server event handler for client validation responses
addEvent("sv2l:cameraPositionValidated", true)
addEventHandler("sv2l:cameraPositionValidated", root, function(result)
    CameraValidation.handleValidationResponse(result)
end)
