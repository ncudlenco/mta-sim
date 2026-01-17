--- SpatialRelationsCollector: Captures spatial relations of all visible objects relative to camera
--- Outputs per-frame JSON files with object positions, rotations, spatial metadata, and event IDs
---
--- Output structure:
--- {
---   "frameId": 42,
---   "timestamp": 1234567890,
---   "storyId": "story_12345",
---   "cameraId": "spectator_0",
---   "camera": {
---     "position": {"x": 10.5, "y": 20.3, "z": 5.2},
---     "lookAt": {"x": 15.0, "y": 22.0, "z": 5.0},
---     "fov": 70.0,
---     "roll": 0.0
---   },
---   "entities": [
---     {
---       "elementType": "object",
---       "modelId": 2281,
---       "existEventId": "obj_painting_1",
---       "storyObjectId": "obj_painting_1",
---       "objectType": "Laptop",
---       "currentEventId": "a2_11",
---       "position": {"x": 12.0, "y": 21.0, "z": 0.5},
---       "rotation": {"x": 0, "y": 0, "z": 90},
---       "spatial": {
---         "distance": 3.5,
---         "angleHorizontal": 25.3,
---         "angleVertical": -5.2,
---         "direction": "front-left",
---         "inFOV": true
---       }
---     },
---     ...
---   ]
--- }
---
--- @classmod SpatialRelationsCollector
--- @author Claude Code
--- @license MIT

SpatialRelationsCollector = class(ArtifactCollector, function(o, config)
    ArtifactCollector.init(o, "SpatialRelationsCollector", config)

    o.cameraId = config.cameraId or "unknown"
    o.spatialRelationsFPS = config.spatialRelationsFPS or 0
    o.includeInvisible = config.includeInvisible or false
    o.maxDistance = config.maxDistance or 0
    o.framesPerSecond = config.framesPerSecond or 30
    o.captureInterval = 1
    o.frameCounter = 0

    -- Object relations configuration
    o.includeObjectRelations = config.includeObjectRelations
    if o.includeObjectRelations == nil then
        o.includeObjectRelations = true  -- Default to enabled
    end

    -- Deduplication state (skip identical frames)
    o.lastComparisonKey = nil  -- Store previous frame's content hash for comparison
    o.lastFrameId = nil        -- Track which frame the lastComparisonKey is from
    o.skippedFrames = 0        -- Counter for logging

    -- Calculate frame skip interval
    if o.spatialRelationsFPS > 0 and o.spatialRelationsFPS < o.framesPerSecond then
        o.captureInterval = math.floor(o.framesPerSecond / o.spatialRelationsFPS)
    end

    if DEBUG then
        print(string.format("[SpatialRelationsCollector] Initialized: cameraId=%s, fps=%d, interval=%d, includeInvisible=%s, maxDistance=%d, includeObjectRelations=%s",
            o.cameraId, o.spatialRelationsFPS, o.captureInterval, tostring(o.includeInvisible), o.maxDistance, tostring(o.includeObjectRelations)))
    end
end)

--- Main collection method called by ArtifactCollectionManager
--- @param frameContext table Context data for frame (storyId, cameraId, timestamp, etc.)
--- @param frameId number Current frame ID
--- @param callback function Callback(success, width, height) to invoke when done
function SpatialRelationsCollector:collectAndSave(frameContext, frameId, callback)
    self.frameCounter = self.frameCounter + 1

    -- Check frame skip
    if self.captureInterval > 1 and (self.frameCounter % self.captureInterval ~= 0) then
        -- Skip this frame
        if callback then
            callback(true, 0, 0)
        end
        return
    end

    -- Get camera data
    local camera = self:getCameraMatrix()
    if not camera then
        if DEBUG then
            print("[SpatialRelationsCollector] ERROR: Could not get camera matrix for " .. self.cameraId)
        end
        if callback then
            callback(false, 0, 0)
        end
        return
    end

    -- Enumerate all entities
    local entities = self:enumerateAllEntities()

    -- Build entity data
    local entityData = {}
    local visibleCount = 0

    for _, entityInfo in ipairs(entities) do
        local data = self:buildEntityData(entityInfo.element, entityInfo.elementType, camera)

        if data then
            -- Filter by visibility if configured
            if not self.includeInvisible and not data.spatial.inFOV then
                -- Skip invisible objects
            else
                table.insert(entityData, data)
                if data.spatial.inFOV then
                    visibleCount = visibleCount + 1
                end
            end
        end
    end

    -- Calculate pairwise object relations if enabled
    local objectRelations = {}
    if self.includeObjectRelations and #entityData > 1 then
        objectRelations = self:calculatePairwiseRelations(entityData)
    end

    -- Build JSON structure
    local outputData = {
        frameId = frameId,
        timestamp = frameContext.timestamp or 0,
        storyId = frameContext.storyId or "unknown",
        cameraId = self.cameraId,
        camera = {
            position = {x = camera.x, y = camera.y, z = camera.z},
            lookAt = {x = camera.lx, y = camera.ly, z = camera.lz},
            fov = camera.fov,
            roll = camera.roll
        },
        entities = entityData,
        objectRelations = objectRelations
    }

    -- Deduplication: Compare content with previous frame (excluding frameId and timestamp)
    local contentForComparison = self:buildComparisonKey(outputData)

    if self.lastComparisonKey and self.lastComparisonKey == contentForComparison then
        -- Identical to previous frame, skip write
        self.skippedFrames = self.skippedFrames + 1
        if DEBUG then
            print(string.format("[SpatialRelationsCollector] Frame %d: SKIPPED (identical to frame %d), total skipped: %d",
                frameId, self.lastFrameId, self.skippedFrames))
        end
        if callback then
            callback(true, 0, 0)
        end
        return
    end

    -- Different from previous, update state and write to file
    self.lastComparisonKey = contentForComparison
    self.lastFrameId = frameId

    local success = self:writeToFile(outputData, frameId, frameContext.storyId)

    if DEBUG then
        print(string.format("[SpatialRelationsCollector] Frame %d: %d entities, %d in FOV, %d relations, written=%s",
            frameId, #entityData, visibleCount, #objectRelations, tostring(success)))
    end

    if callback then
        callback(success, 0, 0)
    end
end

--- Enumerate all game entities (objects, peds, vehicles, etc.)
--- @return table Array of {element, elementType} entries
function SpatialRelationsCollector:enumerateAllEntities()
    local entities = {}

    -- Get all element types
    local elementTypes = {
        {type = "object", elements = getElementsByType("object")},
        {type = "ped", elements = getElementsByType("ped")},
        {type = "vehicle", elements = getElementsByType("vehicle")},
        {type = "pickup", elements = getElementsByType("pickup")}
    }

    -- Flatten into single array with type annotation
    for _, typeData in ipairs(elementTypes) do
        if typeData.elements then
            for _, element in ipairs(typeData.elements) do
                if isElement(element) then
                    table.insert(entities, {
                        element = element,
                        elementType = typeData.type
                    })
                end
            end
        end
    end

    return entities
end

--- Build entity data structure with spatial relations
--- @param element userdata MTA element
--- @param elementType string Element type ("object", "ped", "vehicle", etc.)
--- @param camera table Camera data {x, y, z, lx, ly, lz, fov, roll}
--- @return table|nil Entity data structure or nil if element invalid
function SpatialRelationsCollector:buildEntityData(element, elementType, camera)
    if not isElement(element) then
        return nil
    end

    -- Get element position
    local position = self:getElementPosition(element)
    if not position then
        return nil
    end

    -- Filter by distance if configured
    if self.maxDistance > 0 then
        local distance = (position - Vector3(camera.x, camera.y, camera.z)):getLength()
        if distance > self.maxDistance then
            return nil
        end
    end

    -- Get element rotation
    local rotation = self:getElementRotation(element)

    -- Get model ID
    local modelId = element.model or 0

    -- Calculate spatial data
    local spatial = self:calculateSpatialData(camera, position)

    -- Build base entity structure
    local entityData = {
        elementType = elementType,
        modelId = modelId,
        position = {x = position.x, y = position.y, z = position.z},
        rotation = {x = rotation.x, y = rotation.y, z = rotation.z},
        spatial = spatial
    }

    -- Add story-specific data based on element type
    if elementType == "ped" then
        -- Handle actor/ped
        local actorId = self:getStoryActorId(element)
        if actorId then
            -- Story actor - validate existEventId against graph (false = not an object)
            local existEventId = self:getExistEventIdFromGraph(actorId, false)
            entityData.existEventId = existEventId  -- Will be nil if not in graph
            entityData.storyActorId = actorId
            entityData.currentEventId = self:getCurrentEventIdForActor(element)
            entityData.currentActionName = element:getData('currentGraphActionName')
        else
            -- Non-story ped
            entityData.existEventId = nil
            entityData.storyActorId = nil
            entityData.currentEventId = nil
        end
    elseif elementType == "object" then
        -- Handle object
        local storyObjInfo = self:getStoryObjectInfo(element)
        if storyObjInfo then
            -- Story object - use objectMap reverse lookup to get graph ID (true = is an object)
            local existEventId = self:getExistEventIdFromGraph(storyObjInfo.objectId, true)
            entityData.existEventId = existEventId  -- Will be nil if not mapped to graph
            entityData.storyObjectId = storyObjInfo.objectId
            entityData.objectType = storyObjInfo.objectType  -- e.g., "Cigarette", "MobilePhone", "Laptop"
            entityData.currentEventId = self:getCurrentEventIdForObject(storyObjInfo.objectId)
        else
            -- Non-story object
            entityData.existEventId = nil
            entityData.storyObjectId = nil
            entityData.objectType = nil
            entityData.currentEventId = nil
        end
    else
        -- Other element types (vehicle, pickup, etc.)
        entityData.existEventId = nil
    end

    return entityData
end

--- Get camera matrix from spectator
--- @return table|nil Camera data {x, y, z, lx, ly, lz, fov, roll} or nil if not found
function SpatialRelationsCollector:getCameraMatrix()
    if not CURRENT_STORY or not CURRENT_STORY.Spectators then
        return nil
    end

    -- Find spectator by camera ID
    local spectator = FirstOrDefault(CURRENT_STORY.Spectators, function(spec)
        return spec:getData('id') == self.cameraId
    end)

    if not spectator then
        return nil
    end

    local x, y, z, lx, ly, lz = spectator:getCameraMatrix()
    local roll = spectator:getData('cameraRoll') or 0
    local fov = spectator:getData('cameraFOV') or 70

    return {
        x = x, y = y, z = z,
        lx = lx, ly = ly, lz = lz,
        roll = roll,
        fov = fov
    }
end

--- Get element position
--- @param element userdata MTA element
--- @return Vector3|nil Position or nil if unavailable
function SpatialRelationsCollector:getElementPosition(element)
    if not element then
        return nil
    end

    -- Try element.position first (for objects)
    if element.position and element.position.x then
        return Vector3(element.position.x, element.position.y, element.position.z)
    end

    -- Try getElementPosition (for peds, vehicles)
    if getElementPosition then
        local x, y, z = getElementPosition(element)
        if x then
            return Vector3(x, y, z)
        end
    end

    return nil
end

--- Get element rotation
--- @param element userdata MTA element
--- @return table Rotation {x, y, z}
function SpatialRelationsCollector:getElementRotation(element)
    if not element then
        return {x = 0, y = 0, z = 0}
    end

    -- Try element.rotation first (for objects)
    if element.rotation and element.rotation.x then
        return {x = element.rotation.x, y = element.rotation.y, z = element.rotation.z}
    end

    -- Try getElementRotation (for peds, vehicles)
    if getElementRotation then
        local rx, ry, rz = getElementRotation(element)
        if rx then
            return {x = rx, y = ry, z = rz}
        end
    end

    return {x = 0, y = 0, z = 0}
end

--- Look up story object info from element
--- @param element userdata MTA element
--- @return table|nil {objectId, objectType} or nil if not a story object
function SpatialRelationsCollector:getStoryObjectInfo(element)
    if not CURRENT_STORY or not CURRENT_STORY.CurrentEpisode then
        return nil
    end

    -- Check episode objects
    for _, storyObj in ipairs(CURRENT_STORY.CurrentEpisode.Objects) do
        if storyObj.instance == element then
            return {
                objectId = storyObj.ObjectId,
                objectType = storyObj.type  -- e.g., "Laptop", "Cigarette", "MobilePhone"
            }
        end
    end

    return nil
end

--- Get graph object ID from episode object ID using objectMap reverse lookup
--- @param episodeObjectId string Episode object ID (e.g., "15_classroom1")
--- @return string|nil Graph object ID (e.g., "obj_0") or nil if not mapped
function SpatialRelationsCollector:getGraphObjectIdFromEpisodeId(episodeObjectId)
    if not CURRENT_STORY or not CURRENT_STORY.objectMap then
        return nil
    end

    -- objectMap[episodeObjectId] = [{value = graphObjectId, chainId = ...}]
    local mappings = CURRENT_STORY.objectMap[episodeObjectId]
    if mappings and #mappings > 0 then
        return mappings[1].value  -- Return the first mapped graph object ID
    end

    return nil
end

--- Check if an ID has an "Exists" event in the graph
--- For objects: pass isObject=true to use objectMap reverse lookup and verify materialization
--- @param id string The ID to check (actor ID or episode object ID)
--- @param isObject boolean True if this is an object ID (needs reverse lookup)
--- @return string|nil The graph event ID if it exists with Action=="Exists", nil otherwise
function SpatialRelationsCollector:getExistEventIdFromGraph(id, isObject)
    if not CURRENT_STORY or not CURRENT_STORY.graph then
        return nil
    end

    local graphId = id

    -- For objects, look up the graph ID from the episode object ID
    if isObject then
        graphId = self:getGraphObjectIdFromEpisodeId(id)
        if not graphId then
            return nil  -- Object not mapped to graph
        end

        -- Check if this SPECIFIC object was the one selected at runtime
        -- materializedObjects[graphId].physicalObjectId = the episode object ID that was chosen
        if CURRENT_STORY.materializedObjects and CURRENT_STORY.materializedObjects[graphId] then
            local materialized = CURRENT_STORY.materializedObjects[graphId]
            if materialized.physicalObjectId ~= id then
                return nil  -- A different object with same graph ID was selected, not this one
            end
        else
            return nil  -- Object not currently materialized (not used at runtime)
        end
    end

    -- Check if this ID exists as a key in the graph with Action=="Exists"
    local event = CURRENT_STORY.graph[graphId]
    if event and event.Action == "Exists" then
        return graphId  -- Return the graph ID, not the episode ID
    end

    return nil
end

--- Look up story actor ID from element
--- @param element userdata MTA element
--- @return string|nil Story actor ID or nil if not a story actor
function SpatialRelationsCollector:getStoryActorId(element)
    if not CURRENT_STORY or not CURRENT_STORY.CurrentEpisode then
        return nil
    end

    -- Check episode peds
    local actorId = element:getData('id')
    if actorId then
        -- Verify it's a story actor
        local isStoryActor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped)
            return ped:getData('id') == actorId
        end)

        if isStoryActor then
            return actorId
        end
    end

    return nil
end

--- Get current event ID for an actor
--- @param actor userdata Actor element
--- @return string|nil Current event ID or nil
function SpatialRelationsCollector:getCurrentEventIdForActor(actor)
    if not actor then
        return nil
    end

    -- Actors directly store their current event ID
    return actor:getData('currentGraphEventId')
end

--- Get current event ID for an object
--- @param storyObjectId string Story object ID
--- @return string|nil Current event ID or nil
function SpatialRelationsCollector:getCurrentEventIdForObject(storyObjectId)
    if not CURRENT_STORY or not CURRENT_STORY.materializedObjects then
        return nil
    end

    -- Look up object in materializedObjects
    -- Structure: materializedObjects[objectId] = {pos, rotation, chainId, actorId, element, physicalObjectId}
    local materialized = CURRENT_STORY.materializedObjects[storyObjectId]

    if not materialized or not materialized.actorId then
        -- Object not currently materialized or not in use
        return nil
    end

    -- Find the actor who's using this object
    local actor = FirstOrDefault(CURRENT_STORY.CurrentEpisode.peds, function(ped)
        return ped:getData('id') == materialized.actorId
    end)

    if not actor then
        return nil
    end

    -- Get the actor's current event ID (the event they're currently executing)
    return actor:getData('currentGraphEventId')
end

--- Calculate spatial relations relative to camera
--- @param camera table Camera data {x, y, z, lx, ly, lz, fov, roll}
--- @param position Vector3 Entity position
--- @return table Spatial data {distance, angleHorizontal, angleVertical, direction, inFOV}
function SpatialRelationsCollector:calculateSpatialData(camera, position)
    local cameraPos = Vector3(camera.x, camera.y, camera.z)
    local cameraLookAtPos = Vector3(camera.lx, camera.ly, camera.lz)

    -- Distance
    local distance = (position - cameraPos):getLength()

    -- Forward direction
    local forward = cameraLookAtPos - cameraPos
    forward:normalize()

    -- Direction to object
    local toObject = position - cameraPos
    local toObjectLength = toObject:getLength()

    local angleHorizontal = 0
    local angleVertical = 0

    if toObjectLength > 0.001 then
        toObject:normalize()

        -- Horizontal angle (project to XY plane)
        local forwardHoriz = Vector3(forward.x, forward.y, 0)
        local toObjectHoriz = Vector3(toObject.x, toObject.y, 0)

        local forwardHorizLength = forwardHoriz:getLength()
        local toObjectHorizLength = toObjectHoriz:getLength()

        if forwardHorizLength > 0.001 and toObjectHorizLength > 0.001 then
            forwardHoriz:normalize()
            toObjectHoriz:normalize()

            -- Use atan2 for signed angle
            local cross = forwardHoriz.x * toObjectHoriz.y - forwardHoriz.y * toObjectHoriz.x
            local dot = forwardHoriz.x * toObjectHoriz.x + forwardHoriz.y * toObjectHoriz.y
            angleHorizontal = math.deg(math.atan2(cross, dot))
        end

        -- Vertical angle
        local horizontalDist = math.sqrt(toObject.x * toObject.x + toObject.y * toObject.y)
        if horizontalDist > 0.001 then
            angleVertical = math.deg(math.atan2(toObject.z, horizontalDist))
        end
    end

    -- Direction bucket
    local direction = self:getDirectionBucket(angleHorizontal, angleVertical)

    -- FOV check
    local inFOV = self:isInFOV(camera, position)

    return {
        distance = distance,
        angleHorizontal = angleHorizontal,
        angleVertical = angleVertical,
        direction = direction,
        inFOV = inFOV
    }
end

--- Determine direction bucket from angles
--- @param angleH number Horizontal angle in degrees (-180 to 180)
--- @param angleV number Vertical angle in degrees (-90 to 90)
--- @return string Direction bucket: "front", "back", "left", "right", "front-left", "front-right", "back-left", "back-right", "above", "below"
function SpatialRelationsCollector:getDirectionBucket(angleH, angleV)
    -- Primarily vertical
    if math.abs(angleV) >= 45 then
        return angleV > 0 and "above" or "below"
    end

    -- Horizontal buckets
    local absH = math.abs(angleH)

    if absH <= 22.5 then
        return "front"
    elseif absH >= 157.5 then
        return "back"
    elseif angleH > 0 then
        -- Left side (positive angle)
        if angleH <= 67.5 then
            return "front-left"
        elseif angleH <= 112.5 then
            return "left"
        else
            return "back-left"
        end
    else
        -- Right side (negative angle)
        if angleH >= -67.5 then
            return "front-right"
        elseif angleH >= -112.5 then
            return "right"
        else
            return "back-right"
        end
    end
end

--- Check if position is within camera FOV
--- Based on Region.lua:318-359 FOV calculation
--- @param camera table Camera data {x, y, z, lx, ly, lz, fov, roll}
--- @param position Vector3 Entity position
--- @return boolean True if in FOV, false otherwise
function SpatialRelationsCollector:isInFOV(camera, position)
    local cameraPos = Vector3(camera.x, camera.y, camera.z)
    local cameraLookAtPos = Vector3(camera.lx, camera.ly, camera.lz)

    -- Calculate view direction
    local viewDir = cameraLookAtPos - cameraPos
    local viewDirLength = viewDir:getLength()
    if viewDirLength < 0.001 then
        return false
    end
    viewDir:normalize()

    -- Build coordinate system
    local worldUp = Vector3(0, 1, 0)
    local right = viewDir:cross(worldUp)
    local rightLength = right:getLength()
    if rightLength < 0.001 then
        -- View direction parallel to world up, use fallback
        right = Vector3(1, 0, 0)
    else
        right:normalize()
    end
    local up = right:cross(viewDir)
    up:normalize()

    -- Apply roll
    if camera.roll and camera.roll ~= 0 then
        local rollRad = math.rad(camera.roll)
        local cosRoll = math.cos(rollRad)
        local sinRoll = math.sin(rollRad)

        local rightX = right.x * cosRoll - up.x * sinRoll
        local rightY = right.y * cosRoll - up.y * sinRoll
        local rightZ = right.z * cosRoll - up.z * sinRoll

        local upX = right.x * sinRoll + up.x * cosRoll
        local upY = right.y * sinRoll + up.y * cosRoll
        local upZ = right.z * sinRoll + up.z * cosRoll

        right = Vector3(rightX, rightY, rightZ)
        up = Vector3(upX, upY, upZ)
    end

    -- Vector to position
    local camToPos = position - cameraPos
    local camToPosLength = camToPos:getLength()
    if camToPosLength < 0.001 then
        return true  -- Position at camera
    end
    camToPos:normalize()

    -- Calculate angles
    local dotView = viewDir:dot(camToPos)
    local dotRight = right:dot(camToPos)
    local dotUp = up:dot(camToPos)

    -- Clamp to avoid acos domain errors
    dotView = math.max(-1, math.min(1, dotView))

    local angleView = math.acos(dotView)
    local angleHorizontal = math.atan2(dotRight, dotView)
    local angleVertical = math.atan2(dotUp, dotView)

    -- Check FOV
    local fovRad = math.rad(camera.fov)
    return angleView <= (fovRad / 2)
       and math.abs(angleHorizontal) <= (fovRad / 2)
       and math.abs(angleVertical) <= (fovRad / 2)
end

--- Calculate pairwise spatial relations between all entities
--- Uses unidirectional pairs (A→B where index(A) < index(B)) to avoid duplicates
--- @param entityData table Array of entity data with positions and rotations
--- @return table Array of pairwise relation objects
function SpatialRelationsCollector:calculatePairwiseRelations(entityData)
    local relations = {}

    for i = 1, #entityData do
        for j = i + 1, #entityData do  -- j > i for unidirectional pairs
            local entityA = entityData[i]
            local entityB = entityData[j]

            local posA = Vector3(entityA.position.x, entityA.position.y, entityA.position.z)
            local posB = Vector3(entityB.position.x, entityB.position.y, entityB.position.z)

            local relation = self:calculateEntityToEntityRelation(posA, posB, entityA.rotation, i, j, entityA, entityB)
            table.insert(relations, relation)
        end
    end

    return relations
end

--- Calculate spatial relation from entity A to entity B
--- @param posA Vector3 Position of entity A
--- @param posB Vector3 Position of entity B
--- @param rotA table Rotation of entity A {x, y, z} (for forward direction)
--- @param indexA number Index of entity A in entities array (1-based)
--- @param indexB number Index of entity B in entities array (1-based)
--- @param entityA table Entity A data (for ID lookup)
--- @param entityB table Entity B data (for ID lookup)
--- @return table Relation data with distance, angles, direction, and IDs
function SpatialRelationsCollector:calculateEntityToEntityRelation(posA, posB, rotA, indexA, indexB, entityA, entityB)
    -- Distance
    local distance = (posB - posA):getLength()

    -- Direction from A to B
    local toB = posB - posA

    local angleHorizontal = 0
    local angleVertical = 0

    if distance > 0.001 then
        -- Calculate forward direction of entity A from its rotation (Z rotation = heading)
        local headingRad = math.rad(rotA.z or 0)
        local forwardA = Vector3(math.sin(headingRad), math.cos(headingRad), 0)

        -- Horizontal angle (project to XY plane)
        local toBHoriz = Vector3(toB.x, toB.y, 0)
        local toBHorizLength = toBHoriz:getLength()

        if toBHorizLength > 0.001 then
            toBHoriz:normalize()

            -- Signed angle from forwardA to toBHoriz
            local cross = forwardA.x * toBHoriz.y - forwardA.y * toBHoriz.x
            local dot = forwardA.x * toBHoriz.x + forwardA.y * toBHoriz.y
            angleHorizontal = math.deg(math.atan2(cross, dot))
        end

        -- Vertical angle
        local horizontalDist = math.sqrt(toB.x * toB.x + toB.y * toB.y)
        if horizontalDist > 0.001 then
            angleVertical = math.deg(math.atan2(toB.z, horizontalDist))
        end
    end

    -- Direction bucket (reuse existing method)
    local direction = self:getDirectionBucket(angleHorizontal, angleVertical)

    -- Get IDs for the entities (prefer existEventId, then storyActorId/storyObjectId)
    local fromId = entityA.existEventId or entityA.storyActorId or entityA.storyObjectId
    local toId = entityB.existEventId or entityB.storyActorId or entityB.storyObjectId

    return {
        fromIndex = indexA - 1,  -- Convert to 0-based for JSON
        toIndex = indexB - 1,
        fromId = fromId,
        toId = toId,
        distance = distance,
        angleHorizontal = angleHorizontal,
        angleVertical = angleVertical,
        direction = direction
    }
end

--- Build comparison key for frame deduplication
--- Excludes frameId and timestamp since those always change between frames
--- @param outputData table The complete output data structure
--- @return string Comparison key (JSON string of content-only data)
function SpatialRelationsCollector:buildComparisonKey(outputData)
    -- Build a table with only the content that matters for comparison
    -- Exclude frameId and timestamp since they always change
    local contentOnly = {
        cameraId = outputData.cameraId,
        camera = outputData.camera,
        entities = outputData.entities,
        objectRelations = outputData.objectRelations
    }

    return toJSON(contentOnly, true) or ""
end

--- Write spatial relations data to JSON file
--- @param data table Spatial relations data structure
--- @param frameId number Frame ID
--- @param storyId string Story ID
--- @return boolean True if successful, false otherwise
function SpatialRelationsCollector:writeToFile(data, frameId, storyId)
    if not LOAD_FROM_GRAPH then
        if DEBUG then
            print("[SpatialRelationsCollector] ERROR: LOAD_FROM_GRAPH not set")
        end
        return false
    end

    -- Build output path: [LOAD_FROM_GRAPH]_out/[storyId]/[cameraId]/frame_XXXX_spatial_relations.json
    local basePath = LOAD_FROM_GRAPH .. "_out"
    local storyPath = basePath .. "/" .. (storyId or "unknown")
    local cameraPath = storyPath .. "/" .. self.cameraId

    -- Format frame ID with leading zeros
    local frameIdStr = string.format("%04d", frameId)
    local filename = "frame_" .. frameIdStr .. "_spatial_relations.json"
    local filePath = cameraPath .. "/" .. filename

    -- Serialize to JSON
    local jsonStr = toJSON(data, true)  -- true for compact format
    if not jsonStr then
        if DEBUG then
            print("[SpatialRelationsCollector] ERROR: Failed to serialize data to JSON")
        end
        return false
    end

    -- Write to file
    local file = fileCreate(filePath)
    if not file then
        if DEBUG then
            print("[SpatialRelationsCollector] ERROR: Failed to create file: " .. filePath)
        end
        return false
    end

    fileWrite(file, jsonStr)
    fileClose(file)

    return true
end
