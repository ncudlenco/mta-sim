--- Client-side camera validation using MTA raycasting functions
--- Receives validation requests from server, performs raycasting, sends results back
--- Pure async event-driven architecture with immediate response

CameraValidationClient = {}

--- Check if a point is inside a 2D polygon using ray-casting algorithm
--- Ported from Region:IsPointInside2() server-side method
--- @param point table {x, y} point to test
--- @param vertices table Array of {x, y} polygon vertices
--- @return boolean True if point is inside polygon
function CameraValidationClient.isPointInPolygon(point, vertices)
    if not vertices or #vertices < 3 then
        return false
    end

    local inside = false
    local j = #vertices

    for i = 1, #vertices do
        local xi, yi = vertices[i].x or vertices[i][1], vertices[i].y or vertices[i][2]
        local xj, yj = vertices[j].x or vertices[j][1], vertices[j].y or vertices[j][2]

        if ((yi > point.y) ~= (yj > point.y)) and
           (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi) then
            inside = not inside
        end

        j = i
    end

    return inside
end

--- Validate camera position using client-side MTA functions
--- @param cameraPos table {x, y, z} camera position
--- @param subjectPos table {x, y, z} subject position
--- @param regionPolygon table Array of 2D vertices {{x, y}, ...}
--- @param options table Validation options
--- @return table Validation result {isValid, reasons, details}
function CameraValidationClient.validatePosition(cameraPos, subjectPos, regionPolygon, options)
    local isValid = true
    local reasons = {}
    local details = {}

    -- Check line of sight from camera to subject
    if options.checkLineOfSight then
        local losCheck = isLineOfSightClear(
            cameraPos.x, cameraPos.y, cameraPos.z,
            subjectPos.x, subjectPos.y, subjectPos.z,
            true,  -- checkBuildings
            true,  -- checkVehicles
            false, -- checkPeds (don't check - we want to see through actors)
            true,  -- checkObjects
            false, -- checkDummies
            false, -- seeThroughStuff
            false  -- ignoreSomeObjectsForCamera
        )

        if not losCheck then
            isValid = false
            table.insert(reasons, "line_of_sight_blocked")
            details.lineOfSight = false
        else
            details.lineOfSight = true
        end
    end

    -- Check if camera is within region polygon bounds
    if options.checkRegionBounds and regionPolygon then
        local inBounds = CameraValidationClient.isPointInPolygon(
            {x = cameraPos.x, y = cameraPos.y},
            regionPolygon
        )

        if not inBounds then
            isValid = false
            table.insert(reasons, "outside_region_bounds")
            details.regionBounds = false
        else
            details.regionBounds = true
        end
    end

    return {
        isValid = isValid,
        reasons = reasons,
        details = details
    }
end

--- Incremental adjustment strategy: try positions at decreasing distances
--- @param idealPos table {x, y, z} ideal camera position
--- @param subjectPos table {x, y, z} subject position
--- @param regionPolygon table Region polygon vertices
--- @param params table Camera parameters
--- @param maxAttempts number Maximum attempts (default 10)
--- @return table|nil Valid camera position or nil
function CameraValidationClient.adjustIncremental(idealPos, subjectPos, regionPolygon, params, maxAttempts)
    maxAttempts = maxAttempts or 10

    local direction = {
        x = idealPos.x - subjectPos.x,
        y = idealPos.y - subjectPos.y,
        z = idealPos.z - subjectPos.z
    }

    for i = 1, maxAttempts do
        local factor = 1.0 - (i * 0.1) -- 90%, 80%, 70%, ...
        local testPos = {
            x = subjectPos.x + direction.x * factor,
            y = subjectPos.y + direction.y * factor,
            z = subjectPos.z + direction.z * factor
        }

        local validation = CameraValidationClient.validatePosition(
            testPos, subjectPos, regionPolygon,
            {checkLineOfSight = true, checkRegionBounds = true}
        )

        if validation.isValid then
            return testPos
        end
    end

    return nil
end

--- Slide along wall strategy: use processLineOfSight to find wall hit point
--- @param idealPos table {x, y, z} ideal camera position
--- @param subjectPos table {x, y, z} subject position
--- @param regionPolygon table Region polygon vertices
--- @param params table Camera parameters
--- @return table|nil Valid camera position or nil
function CameraValidationClient.adjustSlideAlongWall(idealPos, subjectPos, regionPolygon, params)
    -- Use processLineOfSight to get detailed collision info
    local hit, hitX, hitY, hitZ, elementHit, normalX, normalY, normalZ = processLineOfSight(
        subjectPos.x, subjectPos.y, subjectPos.z,
        idealPos.x, idealPos.y, idealPos.z,
        true,  -- checkBuildings
        true,  -- checkVehicles
        false, -- checkPeds
        true,  -- checkObjects
        false, -- checkDummies
        false, -- seeThroughStuff
        false, -- ignoreSomeObjectsForCamera
        false  -- returnSimpleCollision
    )

    if hit and hitX and normalX then
        -- Offset from hit point along wall normal
        local wallOffset = params.wallOffset or 0.5
        local testPos = {
            x = hitX + normalX * wallOffset,
            y = hitY + normalY * wallOffset,
            z = hitZ + normalZ * wallOffset
        }

        -- Validate the adjusted position
        local validation = CameraValidationClient.validatePosition(
            testPos, subjectPos, regionPolygon,
            {checkLineOfSight = true, checkRegionBounds = true}
        )

        if validation.isValid then
            return testPos
        end
    end

    return nil
end

--- Rotate around subject strategy: try positions at different angles
--- @param idealPos table {x, y, z} ideal camera position
--- @param subjectPos table {x, y, z} subject position
--- @param regionPolygon table Region polygon vertices
--- @param params table Camera parameters
--- @param maxAttempts number Maximum attempts (default 12 = 30° increments)
--- @return table|nil Valid camera position or nil
function CameraValidationClient.adjustRotateAroundSubject(idealPos, subjectPos, regionPolygon, params, maxAttempts)
    maxAttempts = maxAttempts or 12

    local direction = {
        x = idealPos.x - subjectPos.x,
        y = idealPos.y - subjectPos.y
    }
    local distance = math.sqrt(direction.x * direction.x + direction.y * direction.y)
    local angleIncrement = math.rad(360 / maxAttempts)

    for i = 1, maxAttempts do
        local angle = angleIncrement * i
        local cosAngle = math.cos(angle)
        local sinAngle = math.sin(angle)

        local testPos = {
            x = subjectPos.x + (direction.x * cosAngle - direction.y * sinAngle),
            y = subjectPos.y + (direction.x * sinAngle + direction.y * cosAngle),
            z = idealPos.z
        }

        local validation = CameraValidationClient.validatePosition(
            testPos, subjectPos, regionPolygon,
            {checkLineOfSight = true, checkRegionBounds = true}
        )

        if validation.isValid then
            return testPos
        end
    end

    return nil
end

--- Find valid camera position using specified strategy
--- @param idealPos table {x, y, z} ideal camera position
--- @param subjectPos table {x, y, z} subject position
--- @param regionPolygon table Region polygon vertices
--- @param params table Camera parameters
--- @param options table {strategy, maxAttempts}
--- @return table|nil Valid camera position or nil
function CameraValidationClient.findValidPosition(idealPos, subjectPos, regionPolygon, params, options)
    local strategy = options.strategy or "incremental"
    local maxAttempts = options.maxAttempts or 10

    if strategy == "incremental" then
        return CameraValidationClient.adjustIncremental(idealPos, subjectPos, regionPolygon, params, maxAttempts)
    elseif strategy == "slide" then
        return CameraValidationClient.adjustSlideAlongWall(idealPos, subjectPos, regionPolygon, params)
    elseif strategy == "rotate" then
        return CameraValidationClient.adjustRotateAroundSubject(idealPos, subjectPos, regionPolygon, params, maxAttempts)
    end

    return nil
end

--- Handle validation request from server
--- @param data table Request data from server
function CameraValidationClient.handleValidationRequest(data)
    -- Validate the ideal position
    local validation = CameraValidationClient.validatePosition(
        data.idealCameraPos,
        data.subjectPos,
        data.regionPolygon,
        data.options or {}
    )

    local result = {
        requestId = data.requestId,
        isValid = validation.isValid,
        finalCameraPos = nil,
        adjustmentMade = false,
        reasons = validation.reasons
    }

    -- If invalid, try to find valid position using adjustment strategy
    if not validation.isValid then
        local validPos = CameraValidationClient.findValidPosition(
            data.idealCameraPos,
            data.subjectPos,
            data.regionPolygon,
            data.params or {},
            data.options or {}
        )

        if validPos then
            result.finalCameraPos = validPos
            result.adjustmentMade = true
        end
    end

    -- Send result back to server
    triggerServerEvent("sv2l:cameraPositionValidated", localPlayer, result)
end

--- Register event handler for validation requests
addEvent("sv2l:validateCameraPosition", true)
addEventHandler("sv2l:validateCameraPosition", root, function(data)
    CameraValidationClient.handleValidationRequest(data)
end)

--- Register event handler for enabling camera clip
addEvent("sv2l:enableCameraClip", true)
addEventHandler("sv2l:enableCameraClip", root, function()
    setCameraClip(true, true)  -- Enable collision with objects and vehicles
end)
