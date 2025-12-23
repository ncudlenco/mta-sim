--- Utility module for validating spatial relations between objects in the global coordinate system.
--- Supports directional relations (left, right, in_front, behind) and positional relations (on, near).
--- Used to enforce spatial constraints when actors select chains and materialize objects.
---
--- @module utils.SpatialCoordinator

SpatialCoordinator = class(function(o)
    --- Distance threshold for "on" relation (vertical and horizontal proximity)
    o.ON_VERTICAL_THRESHOLD = 0.8 -- Z-axis distance
    o.ON_HORIZONTAL_THRESHOLD = 2.0 -- XY-plane distance

    --- Distance threshold for directional relations (left, right, in_front, behind)
    o.DIRECTIONAL_DISTANCE_THRESHOLD = 5.0

    --- Distance threshold for "near" relation (3D Euclidean distance)
    o.NEAR_THRESHOLD = 5.0

    --- Angle tolerance for directional relations (degrees)
    --- Objects within ±45 degrees are considered in that direction
    o.DIRECTIONAL_ANGLE_TOLERANCE = 45

    --- Approximate radii for common object types (in GTA units)
    --- Used for dynamic "near" threshold calculation
    o.OBJECT_TYPE_RADII = {
        -- Furniture
        ["Chair"] = 0.7,
        ["Desk"] = 1.5,
        ["Table"] = 1.2,
        ["Bed"] = 1.5,
        ["Sofa"] = 1.5,
        ["Armchair"] = 0.9,

        -- Small objects
        ["Laptop"] = 0.3,
        ["Phone"] = 0.1,
        ["Cigarette"] = 0.05,
        ["Drinks"] = 0.15,
        ["Food"] = 0.2,

        -- Default for unknown types
        ["default"] = 1.0
    }
end)

--- Validate if source position is "on" target position
--- Checks vertical proximity (Z-axis) and horizontal proximity (XY-plane)
---
--- @param sourcePos table Vector3 position of source object
--- @param targetPos table Vector3 position of target object
--- @return boolean True if source is on target
function SpatialCoordinator:ValidateOn(sourcePos, targetPos)
    if not sourcePos or not targetPos then
        return false
    end

    -- Check vertical distance (source should be above or at same level as target)
    local verticalDist = math.abs(sourcePos.z - targetPos.z)

    -- Check horizontal distance (source should be close in XY plane)
    local horizontalDist = math.sqrt(
        (sourcePos.x - targetPos.x)^2 +
        (sourcePos.y - targetPos.y)^2
    )

    local isValid = verticalDist <= self.ON_VERTICAL_THRESHOLD and
                    horizontalDist <= self.ON_HORIZONTAL_THRESHOLD

    if DEBUG_SPATIAL then
        print(string.format("[SpatialCoordinator] ValidateOn: vDist=%.2f (%.2f), hDist=%.2f (%.2f) -> %s",
            verticalDist, self.ON_VERTICAL_THRESHOLD,
            horizontalDist, self.ON_HORIZONTAL_THRESHOLD,
            tostring(isValid)))
    end

    return isValid
end

--- Calculate angle between target's forward direction and vector to source
--- Uses global coordinate system based on target's rotation
---
--- @param sourcePos table Vector3 position of source object
--- @param targetPos table Vector3 position of target object
--- @param targetRotation table Rotation of target object {x, y, z} where z is yaw
--- @return number Angle in degrees (-180 to 180)
function SpatialCoordinator:CalculateRelativeAngle(sourcePos, targetPos, targetRotation)
    -- Get target's forward vector from rotation (yaw angle in Z)
    -- In GTA SA, 0 degrees points North (+Y), rotation is counter-clockwise
    local yawRad = math.rad(targetRotation.z or targetRotation[3] or 0)
    local targetForward = Vector3(
        math.sin(yawRad),  -- X component
        math.cos(yawRad),  -- Y component
        0                   -- Z component (2D direction)
    )

    -- Vector from target to source
    local targetToSource = Vector3(
        sourcePos.x - targetPos.x,
        sourcePos.y - targetPos.y,
        0  -- Ignore Z for directional calculations
    )

    -- Normalize
    targetToSource = targetToSource:getNormalized()

    -- Calculate signed angle using atan2
    -- This gives us the angle from target's forward direction to source
    local angle = math.deg(math.atan2(
        targetForward.x * targetToSource.y - targetForward.y * targetToSource.x, -- Cross product Z component
        targetForward.x * targetToSource.x + targetForward.y * targetToSource.y  -- Dot product
    ))

    if DEBUG_SPATIAL then
        print(string.format("[SpatialCoordinator] CalculateRelativeAngle: rot.z=%.2f yawRad=%.4f forward=(%.3f,%.3f) toSource=(%.3f,%.3f) angle=%.2f",
            targetRotation.z or targetRotation[3] or 0,
            yawRad,
            targetForward.x, targetForward.y,
            targetToSource.x, targetToSource.y,
            angle))
    end

    return angle
end

--- Validate if source position is to the left of target
--- Left is defined as 45-135 degrees counter-clockwise from target's forward direction
---
--- @param sourcePos table Vector3 position of source object
--- @param targetPos table Vector3 position of target object
--- @param targetRotation table Rotation of target object
--- @return boolean True if source is to the left of target
function SpatialCoordinator:ValidateLeft(sourcePos, targetPos, targetRotation)
    if not sourcePos or not targetPos or not targetRotation then
        return false
    end

    local angle = self:CalculateRelativeAngle(sourcePos, targetPos, targetRotation)

    -- Left is 45 to 135 degrees (counter-clockwise from forward)
    local isValid = angle >= 45 and angle <= 135

    if DEBUG_SPATIAL then
        print(string.format("[SpatialCoordinator] ValidateLeft: angle=%.2f -> %s", angle, tostring(isValid)))
    end

    return isValid
end

--- Validate if source position is to the right of target
--- Right is defined as -135 to -45 degrees (clockwise from target's forward direction)
---
--- @param sourcePos table Vector3 position of source object
--- @param targetPos table Vector3 position of target object
--- @param targetRotation table Rotation of target object
--- @return boolean True if source is to the right of target
function SpatialCoordinator:ValidateRight(sourcePos, targetPos, targetRotation)
    if not sourcePos or not targetPos or not targetRotation then
        return false
    end

    local angle = self:CalculateRelativeAngle(sourcePos, targetPos, targetRotation)

    -- Right is -135 to -45 degrees (clockwise from forward)
    local isValid = angle >= -135 and angle <= -45

    if DEBUG_SPATIAL then
        print(string.format("[SpatialCoordinator] ValidateRight: angle=%.2f -> %s", angle, tostring(isValid)))
    end

    return isValid
end

--- Validate if source position is in front of target
--- In front is defined as -45 to 45 degrees from target's forward direction
---
--- @param sourcePos table Vector3 position of source object
--- @param targetPos table Vector3 position of target object
--- @param targetRotation table Rotation of target object
--- @return boolean True if source is in front of target
function SpatialCoordinator:ValidateInFront(sourcePos, targetPos, targetRotation)
    if not sourcePos or not targetPos or not targetRotation then
        return false
    end

    local angle = self:CalculateRelativeAngle(sourcePos, targetPos, targetRotation)

    -- In front is -45 to 45 degrees from forward direction
    local isValid = (angle >= -45 and angle <= 45)

    if DEBUG_SPATIAL then
        print(string.format("[SpatialCoordinator] ValidateInFront: angle=%.2f -> %s", angle, tostring(isValid)))
    end

    return isValid
end

--- Validate if source position is behind target
--- Behind is defined as outside -135 to 135 degrees (135-180 or -135 to -180)
---
--- @param sourcePos table Vector3 position of source object
--- @param targetPos table Vector3 position of target object
--- @param targetRotation table Rotation of target object
--- @return boolean True if source is behind target
function SpatialCoordinator:ValidateBehind(sourcePos, targetPos, targetRotation)
    if not sourcePos or not targetPos or not targetRotation then
        return false
    end

    local angle = self:CalculateRelativeAngle(sourcePos, targetPos, targetRotation)

    -- Behind is beyond ±135 degrees (either > 135 or < -135)
    local isValid = (angle > 135 or angle < -135)

    if DEBUG_SPATIAL then
        print(string.format("[SpatialCoordinator] ValidateBehind: angle=%.2f -> %s", angle, tostring(isValid)))
    end

    return isValid
end

--- Get radius for an object
--- First tries to get radius from element (if provided), then falls back to type-based lookup
---
--- @param objectType string|nil Object type (e.g., "Chair", "Desk")
--- @param element userdata|nil Optional MTA element to get actual radius from
--- @return number Radius for the object or default
function SpatialCoordinator:GetObjectRadius(objectType, element)
    -- Try element-based approach first (client-side functions)
    if element and isElement(element) then
        -- Try getElementRadius (client-side only, will fail server-side)
        local success, radius = pcall(getElementRadius, element)
        if success and radius and radius > 0 then
            if DEBUG_SPATIAL then
                print(string.format("[SpatialCoordinator] Got element radius: %.2f", radius))
            end
            return radius
        end

        -- Try getElementBoundingBox (client-side only, will fail server-side)
        local bboxSuccess, minX, minY, _minZ, maxX, maxY, _maxZ = pcall(getElementBoundingBox, element)
        if bboxSuccess and minX then
            -- Calculate approximate radius from bounding box
            local width = maxX - minX
            local depth = maxY - minY
            local bboxRadius = math.sqrt(width * width + depth * depth) / 2
            if DEBUG_SPATIAL then
                print(string.format("[SpatialCoordinator] Got element bbox radius: %.2f", bboxRadius))
            end
            return bboxRadius
        end
    end

    -- Fall back to type-based hardcoded lookup
    if not objectType then
        return self.OBJECT_TYPE_RADII["default"]
    end

    return self.OBJECT_TYPE_RADII[objectType] or self.OBJECT_TYPE_RADII["default"]
end

--- Validate if source position is near target
--- Near is defined as 3D Euclidean distance within threshold
--- Threshold can be dynamically calculated based on object types and elements if provided
---
--- @param sourcePos table Vector3 position of source object
--- @param targetPos table Vector3 position of target object
--- @param sourceType string|nil Optional source object type for dynamic threshold
--- @param targetType string|nil Optional target object type for dynamic threshold
--- @param sourceElement userdata|nil Optional source MTA element for accurate radius
--- @param targetElement userdata|nil Optional target MTA element for accurate radius
--- @return boolean True if source is near target
function SpatialCoordinator:ValidateNear(sourcePos, targetPos, sourceType, targetType, sourceElement, targetElement)
    if not sourcePos or not targetPos then
        return false
    end

    -- Calculate 3D Euclidean distance
    local distance = math.sqrt(
        (sourcePos.x - targetPos.x)^2 +
        (sourcePos.y - targetPos.y)^2 +
        (sourcePos.z - targetPos.z)^2
    )

    -- Calculate dynamic threshold based on object types and elements
    local threshold = self.NEAR_THRESHOLD
    if sourceType or targetType or sourceElement or targetElement then
        local sourceRadius = self:GetObjectRadius(sourceType, sourceElement)
        local targetRadius = self:GetObjectRadius(targetType, targetElement)
        -- Near threshold = sum of radii + buffer
        threshold = sourceRadius + targetRadius + 1.0
        if DEBUG_SPATIAL then
            print(string.format("[SpatialCoordinator] Dynamic threshold: %.2f (source:%.2f + target:%.2f + buffer:1.0)",
                threshold, sourceRadius, targetRadius))
        end
    end

    local isValid = distance <= threshold

    if DEBUG_SPATIAL then
        print(string.format("[SpatialCoordinator] ValidateNear: distance=%.2f (%.2f) %s-> %s",
            distance, threshold,
            (sourceType or targetType or sourceElement or targetElement) and "[dynamic] " or "",
            tostring(isValid)))
    end

    return isValid
end

--- Validate a single spatial relation between source and target
---
--- @param sourcePos table Vector3 position of source object
--- @param targetPos table Vector3 position of target object
--- @param targetRotation table Rotation of target object (required for directional relations)
--- @param relationType string Type of relation: "on", "left", "right", "in_front", "behind", "near"
--- @param sourceType string|nil Optional source object type for dynamic "near" threshold
--- @param targetType string|nil Optional target object type for dynamic "near" threshold
--- @param sourceElement userdata|nil Optional source MTA element for accurate radius
--- @param targetElement userdata|nil Optional target MTA element for accurate radius
--- @return boolean True if relation is satisfied
--- @return string|nil Error message if validation failed
function SpatialCoordinator:ValidateRelation(sourcePos, targetPos, targetRotation, relationType, sourceType, targetType, sourceElement, targetElement)
    if not sourcePos or not targetPos then
        return false, "Missing source or target position"
    end

    if relationType == "on" then
        return self:ValidateOn(sourcePos, targetPos), nil
    elseif relationType == "near" then
        return self:ValidateNear(sourcePos, targetPos, sourceType, targetType, sourceElement, targetElement), nil
    elseif relationType == "left" then
        return self:ValidateLeft(sourcePos, targetPos, targetRotation), nil
    elseif relationType == "right" then
        return self:ValidateRight(sourcePos, targetPos, targetRotation), nil
    elseif relationType == "in_front" then
        return self:ValidateInFront(sourcePos, targetPos, targetRotation), nil
    elseif relationType == "behind" then
        return self:ValidateBehind(sourcePos, targetPos, targetRotation), nil
    else
        return false, "Unknown relation type: " .. tostring(relationType)
    end
end

--- Get spatial constraints for an object from the graph
---
--- @param objectId string Object ID from graph (e.g., "laptop", "officeChair")
--- @return table|nil Array of {target, type} relations or nil if no constraints
function SpatialCoordinator:GetSpatialConstraints(objectId)
    if not CURRENT_STORY or not CURRENT_STORY.spatial then
        return nil
    end

    local constraints = CURRENT_STORY.spatial[objectId]
    if constraints and constraints.relations then
        return constraints.relations
    end

    return nil
end

--- Get objects that have spatial constraints pointing TO this object
--- Used for pre-validation: when selecting a POI for object A, check if dependent
--- objects (those with constraints pointing to A) can still find valid candidates
---
--- @param objectId string Object ID to find dependents for (e.g., "officeChair2")
--- @return table Array of {objectId, relationType} for objects that reference this one
function SpatialCoordinator:GetDependentObjects(objectId)
    local dependents = {}
    if not CURRENT_STORY or not CURRENT_STORY.spatial then
        return dependents
    end

    for otherObjectId, constraints in pairs(CURRENT_STORY.spatial) do
        if constraints.relations then
            for _, relation in ipairs(constraints.relations) do
                if relation.target == objectId then
                    table.insert(dependents, {
                        objectId = otherObjectId,
                        relationType = relation.type
                    })
                end
            end
        end
    end

    if DEBUG_SPATIAL and #dependents > 0 then
        print(string.format("[SpatialCoordinator] Found %d dependent objects for %s", #dependents, objectId))
    end

    return dependents
end

--- Validate all spatial constraints for an object against materialized world
--- Checks each spatial relation defined for the object against currently materialized objects
---
--- @param objectId string Source object ID from graph
--- @param candidatePos table Vector3 candidate position for object
--- @param candidateRotation table Rotation of candidate object (optional)
--- @param materializedObjects table Map of objectId -> {pos, rotation, chainId, actorId}
--- @return boolean True if all constraints satisfied
--- @return string Reason if validation failed (empty string if valid)
function SpatialCoordinator:ValidateAllConstraints(objectId, candidatePos, candidateRotation, materializedObjects)
    local constraints = self:GetSpatialConstraints(objectId)

    -- No constraints means validation passes
    if not constraints or #constraints == 0 then
        if DEBUG_SPATIAL then
            print("[SpatialCoordinator] No spatial constraints for " .. objectId)
        end
        return true, ""
    end

    if DEBUG_SPATIAL then
        print("[SpatialCoordinator] Validating " .. #constraints .. " constraints for " .. objectId)
    end

    -- Check each constraint
    for _, relation in ipairs(constraints) do
        local targetObjectId = relation.target
        local relationType = relation.type

        if DEBUG_SPATIAL then
            print(string.format("[SpatialCoordinator] Checking %s %s %s", objectId, relationType, targetObjectId))
        end

        -- Check if target object is materialized
        if materializedObjects and materializedObjects[targetObjectId] then
            local targetData = materializedObjects[targetObjectId]
            local targetPos = targetData.pos
            local targetRotation = targetData.rotation

            -- Get object types from graph for dynamic threshold calculation
            local sourceType = nil
            local targetType = nil
            if CURRENT_STORY and CURRENT_STORY.graph then
                if CURRENT_STORY.graph[objectId] and CURRENT_STORY.graph[objectId].Properties then
                    sourceType = CURRENT_STORY.graph[objectId].Properties.Type
                end
                if CURRENT_STORY.graph[targetObjectId] and CURRENT_STORY.graph[targetObjectId].Properties then
                    targetType = CURRENT_STORY.graph[targetObjectId].Properties.Type
                end
            end

            -- Get element references if available (for client-side radius calculation)
            local sourceElement = targetData.sourceElement or nil
            local targetElement = targetData.element or nil

            -- Validate the relation
            local isValid, errorMsg = self:ValidateRelation(
                candidatePos,
                targetPos,
                targetRotation,
                relationType,
                sourceType,
                targetType,
                sourceElement,
                targetElement
            )

            if not isValid then
                local reason = string.format(
                    "Object %s does not satisfy '%s' relation to %s: %s",
                    objectId,
                    relationType,
                    targetObjectId,
                    errorMsg or "constraint violated"
                )
                if DEBUG_SPATIAL then
                    print("[SpatialCoordinator] Validation FAILED: " .. reason)
                end
                return false, reason
            end

            if DEBUG_SPATIAL then
                print(string.format("[SpatialCoordinator] ✓ %s %s %s", objectId, relationType, targetObjectId))
            end
        else
            if DEBUG_SPATIAL then
                print("[SpatialCoordinator] Target " .. targetObjectId .. " not materialized yet, skipping constraint")
            end
            -- Target not materialized yet, skip this constraint
            -- It will be validated when the target is materialized
        end
    end

    if DEBUG_SPATIAL then
        print("[SpatialCoordinator] All constraints satisfied for " .. objectId)
    end

    return true, ""
end

--- Record an object's materialization in the world
--- Called when an actor selects a chain and the object positions are determined
---
--- @param objectId string Object ID from graph
--- @param position table Vector3 position of object
--- @param rotation table Rotation of object
--- @param chainId string Chain ID that materialized this object
--- @param actorId string Actor ID who materialized this object
--- @param element userdata|nil Optional MTA element reference for accurate radius calculation
--- @param physicalObjectId string|nil Physical object ID in the episode (e.g., "15_classroom1")
function SpatialCoordinator:MaterializeObject(objectId, position, rotation, chainId, actorId, element, physicalObjectId)
    if not CURRENT_STORY then
        return
    end

    if not CURRENT_STORY.materializedObjects then
        CURRENT_STORY.materializedObjects = {}
    end

    CURRENT_STORY.materializedObjects[objectId] = {
        pos = position,
        rotation = rotation,
        chainId = chainId,
        actorId = actorId,
        element = element,
        physicalObjectId = physicalObjectId
    }

    if DEBUG_SPATIAL then
        print(string.format("[SpatialCoordinator] Materialized %s at (%.2f, %.2f, %.2f) by actor %s chain %s physical=%s",
            objectId,
            position.x, position.y, position.z,
            actorId or "none",
            chainId or "unknown",
            physicalObjectId or "nil"))
    end
end

--- Clear all materialized objects (used when restarting story)
function SpatialCoordinator:ClearMaterializedObjects()
    if CURRENT_STORY then
        CURRENT_STORY.materializedObjects = {}
        if DEBUG_SPATIAL then
            print("[SpatialCoordinator] Cleared all materialized objects")
        end
    end
end

return SpatialCoordinator
