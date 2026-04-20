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

SpatialRelationsCollector = class(ArtifactCollector, function(o, visibilityAdapter, coordSpaceWriter, config)
    ArtifactCollector.init(o, "SpatialRelationsCollector", config)

    if not visibilityAdapter then
        error("[SpatialRelationsCollector] Visibility adapter is required")
    end

    o.visibilityAdapter = visibilityAdapter
    o.coordSpaceWriter = coordSpaceWriter  -- may be nil (graceful)
    o.cameraId = config.cameraId or "unknown"
    o.spatialRelationsFPS = config.spatialRelationsFPS or 0
    o.includeInvisible = config.includeInvisible or false
    o.maxDistance = config.maxDistance or 0
    o.framesPerSecond = config.framesPerSecond or 30
    o.fallbackScreenWidth = config.screenWidth or WIDTH_RESOLUTION or 1920
    o.fallbackScreenHeight = config.screenHeight or HEIGHT_RESOLUTION or 1080
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

--- Main collection method called by ArtifactCollectionManager.
--- Asynchronous: a client round-trip is issued via the visibility adapter so
--- `isElementOnScreen` / `isLineOfSightClear` (both client-only) can provide
--- engine-authoritative visibility. JSON is written in the adapter callback.
---
--- @param frameContext table Context data for frame (storyId, cameraId, timestamp, etc.)
--- @param frameId number Current frame ID
--- @param callback function Callback(success, width, height) to invoke when done
function SpatialRelationsCollector:collectAndSave(frameContext, frameId, callback)
    self.frameCounter = self.frameCounter + 1

    if self.captureInterval > 1 and (self.frameCounter % self.captureInterval ~= 0) then
        if callback then callback(true, 0, 0) end
        return
    end

    local camera = self:getCameraMatrix()
    if not camera then
        if DEBUG then
            print("[SpatialRelationsCollector] ERROR: Could not get camera matrix for " .. self.cameraId)
        end
        if callback then callback(false, 0, 0) end
        return
    end

    -- Enumerate + distance-prefilter. Distance is cheap server-side and keeps
    -- the network payload small — we only send candidate elements to the
    -- client for visibility probing.
    local entities = self:enumerateAllEntities()
    local cameraPos = Vector3(camera.x, camera.y, camera.z)
    local candidates = {}
    for _, entityInfo in ipairs(entities) do
        local position = self:getElementPosition(entityInfo.element)
        if position then
            if self.maxDistance <= 0 or (position - cameraPos):getLength() <= self.maxDistance then
                table.insert(candidates, {
                    element = entityInfo.element,
                    elementType = entityInfo.elementType,
                    position = position
                })
            end
        end
    end

    local elementsForRequest = {}
    for i, c in ipairs(candidates) do
        elementsForRequest[i] = c.element
    end

    self.visibilityAdapter:requestVisibility(elementsForRequest, function(success, results, clientViewport)
        local visibility = results or {}
        if not success and DEBUG then
            print("[SpatialRelationsCollector] Visibility request failed; writing entities with unknown visibility")
        end

        -- Resolve viewport+visibleRect from (1) native metadata when present
        -- (Desktop Duplication chrome/crop), else (2) client-reported viewport
        -- (multimodal: no crop), else (3) static WIDTH/HEIGHT fallback.
        local viewportW, viewportH, visibleRect = self:_resolveViewport(clientViewport)

        if self.coordSpaceWriter and frameContext.storyId then
            NativeCaptureMetadata.setClientViewport(clientViewport)
            self.coordSpaceWriter:ensureWritten(frameContext.storyId, self.cameraId)
        end

        local entityData = {}
        local visibleCount = 0

        for i, c in ipairs(candidates) do
            local vis = visibility[i] or {lineOfSight = false}
            local data = self:buildEntityData(c.element, c.elementType, c.position,
                                              camera, vis, viewportW, viewportH, visibleRect)

            if data then
                if self.includeInvisible or data.spatial.visible then
                    table.insert(entityData, data)
                    if data.spatial.visible then
                        visibleCount = visibleCount + 1
                    end
                end
            end
        end

        local objectRelations = {}
        if self.includeObjectRelations and #entityData > 1 then
            objectRelations = self:calculatePairwiseRelations(entityData)
        end

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
            resolution = {width = viewportW, height = viewportH},
            entities = entityData,
            objectRelations = objectRelations
        }

        -- Deduplication (content-only hash excludes frameId + timestamp).
        local contentForComparison = self:buildComparisonKey(outputData)
        if self.lastComparisonKey and self.lastComparisonKey == contentForComparison then
            self.skippedFrames = self.skippedFrames + 1
            if DEBUG then
                print(string.format("[SpatialRelationsCollector] Frame %d: SKIPPED (identical to frame %d), total skipped: %d",
                    frameId, self.lastFrameId, self.skippedFrames))
            end
            if callback then callback(true, 0, 0) end
            return
        end

        self.lastComparisonKey = contentForComparison
        self.lastFrameId = frameId

        local writeSuccess = self:writeToFile(outputData, frameId, frameContext.storyId)

        if DEBUG then
            print(string.format("[SpatialRelationsCollector] Frame %d: %d entities, %d visible, %d relations, written=%s",
                frameId, #entityData, visibleCount, #objectRelations, tostring(writeSuccess)))
        end

        if callback then callback(writeSuccess, 0, 0) end
    end)
end

--- Resolve viewport dims + visibleRect.
--- Priority: native backend metadata (Desktop Duplication chrome + crop info) >
--- client-supplied viewport (no crop, identity) > static fallback.
function SpatialRelationsCollector:_resolveViewport(clientViewport)
    local meta = NativeCaptureMetadata.get()
    if meta then
        return meta.viewport.w, meta.viewport.h, meta.visibleRect
    end
    if clientViewport and clientViewport.w and clientViewport.h then
        return clientViewport.w, clientViewport.h,
            {x = 0, y = 0, w = clientViewport.w, h = clientViewport.h}
    end
    local w = self.fallbackScreenWidth
    local h = self.fallbackScreenHeight
    return w, h, {x = 0, y = 0, w = w, h = h}
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

--- Build entity data structure with spatial relations.
--- Position and distance filtering happen in the caller (enumerate+prefilter
--- pass); this builder only fills in metadata and the spatial/screen/visibility
--- record. Visibility is engine-authoritative, supplied from the client
--- round-trip and gated against the visibleRect (post-crop region).
---
--- @param element userdata MTA element
--- @param elementType string Element type ("object", "ped", "vehicle", etc.)
--- @param position Vector3 Pre-computed world position
--- @param camera table Camera data {x, y, z, lx, ly, lz, fov, roll}
--- @param visibility table {lineOfSight = bool} from ClientVisibilityHandler
--- @param viewportW number Viewport width (for projection)
--- @param viewportH number Viewport height (for projection)
--- @param visibleRect table {x, y, w, h} post-crop region in viewport coords
--- @return table|nil Entity data structure or nil if element invalid
function SpatialRelationsCollector:buildEntityData(element, elementType, position, camera, visibility,
                                                   viewportW, viewportH, visibleRect)
    if not isElement(element) then
        return nil
    end

    -- Get element rotation
    local rotation = self:getElementRotation(element)

    -- Get model ID
    local modelId = element.model or 0

    -- Calculate spatial data (angles + 2D projection + engine visibility)
    local spatial = self:calculateSpatialData(camera, position, visibility,
                                              viewportW, viewportH, visibleRect)

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

--- Calculate spatial relations relative to camera.
--- Angular data (distance, horizontal/vertical angles, direction bucket) is
--- computed here. 2D screen coords are supplied by the client (projected via
--- getScreenFromWorldPosition) — server does no projection math.
---
--- `visible` is the single authoritative "is this entity rendered in the
--- saved frame" flag: the engine-accurate projection says the entity's pixel is inside
--- `visibleRect` (post-crop region in viewport coords — excludes the MTA
--- watermark zone) AND the client's `isLineOfSightClear` raycast against an
--- 8-bbox-corner sample is unobstructed by world geometry / vehicles / peds /
--- objects (the entity itself is excluded from the raycast).
---
--- We deliberately do NOT use `isElementOnScreen`: that engine call tests a
--- generous bounding sphere against an extended frustum and routinely returns
--- true for elements geometrically behind the camera.
---
--- @param camera table Camera data {x, y, z, lx, ly, lz, fov, roll}
--- @param position Vector3 Entity position
--- @param visibility table {lineOfSight = bool} from client
--- @param viewportW number Viewport width (for projection)
--- @param viewportH number Viewport height (for projection)
--- @param visibleRect table {x, y, w, h} post-crop region in viewport coords
--- @return table Spatial data {distance, angleHorizontal, angleVertical, direction, visible, screen}
function SpatialRelationsCollector:calculateSpatialData(camera, position, visibility,
                                                        viewportW, viewportH, visibleRect)
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

        -- Horizontal angle (project to XY plane; GTA:SA is Z-up)
        local forwardHoriz = Vector3(forward.x, forward.y, 0)
        local toObjectHoriz = Vector3(toObject.x, toObject.y, 0)

        local forwardHorizLength = forwardHoriz:getLength()
        local toObjectHorizLength = toObjectHoriz:getLength()

        if forwardHorizLength > 0.001 and toObjectHorizLength > 0.001 then
            forwardHoriz:normalize()
            toObjectHoriz:normalize()

            local cross = forwardHoriz.x * toObjectHoriz.y - forwardHoriz.y * toObjectHoriz.x
            local dot = forwardHoriz.x * toObjectHoriz.x + forwardHoriz.y * toObjectHoriz.y
            angleHorizontal = math.deg(math.atan2(cross, dot))
        end

        local horizontalDist = math.sqrt(toObject.x * toObject.x + toObject.y * toObject.y)
        if horizontalDist > 0.001 then
            angleVertical = math.deg(math.atan2(toObject.z, horizontalDist))
        end
    end

    local direction = self:getDirectionBucket(angleHorizontal, angleVertical)

    local lineOfSight = (visibility and visibility.lineOfSight) == true
    local vrMaxX = visibleRect.x + visibleRect.w
    local vrMaxY = visibleRect.y + visibleRect.h

    -- The client already projected bbox.center and bbox.corners via
    -- `getScreenFromWorldPosition`, which uses the real camera matrix. We read
    -- those results directly. Corners behind the camera come back as nil and
    -- are excluded from the 2D envelope + visible test.
    local bboxCenter = visibility and visibility.bbox and visibility.bbox.center
    local centerScreen = visibility and visibility.bbox and visibility.bbox.centerScreen

    local bboxOut = nil
    local anyCornerInside = false
    if visibility and visibility.bbox and visibility.bbox.corners then
        local worldCorners = visibility.bbox.corners
        local cornersScreen = visibility.bbox.cornersScreen or {}
        local worldCornersOut = {}
        local screenCorners = {}
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local anyInFront = false
        for i, c in ipairs(worldCorners) do
            worldCornersOut[i] = {x = c[1], y = c[2], z = c[3]}
            local cs = cornersScreen[i]
            if cs and cs.x and cs.y then
                screenCorners[i] = {x = cs.x, y = cs.y}
                anyInFront = true
                if cs.x < minX then minX = cs.x end
                if cs.y < minY then minY = cs.y end
                if cs.x > maxX then maxX = cs.x end
                if cs.y > maxY then maxY = cs.y end
                if cs.x >= visibleRect.x and cs.x < vrMaxX
                   and cs.y >= visibleRect.y and cs.y < vrMaxY then
                    anyCornerInside = true
                end
            else
                screenCorners[i] = nil
            end
        end

        if anyInFront then
            -- Clip the 2D envelope to visibleRect so overlays stay inside the
            -- saved image even when one corner projects wildly off-screen.
            local clippedMinX = math.max(minX, visibleRect.x)
            local clippedMinY = math.max(minY, visibleRect.y)
            local clippedMaxX = math.min(maxX, vrMaxX)
            local clippedMaxY = math.min(maxY, vrMaxY)
            bboxOut = {
                worldCenter = bboxCenter and
                    {x = bboxCenter[1], y = bboxCenter[2], z = bboxCenter[3]},
                worldCorners = worldCornersOut,
                screenCorners = screenCorners,
                screenRect = {
                    x = minX,
                    y = minY,
                    w = maxX - minX,
                    h = maxY - minY,
                },
                screenRectClipped = (clippedMaxX > clippedMinX and clippedMaxY > clippedMinY)
                    and {
                        x = clippedMinX,
                        y = clippedMinY,
                        w = clippedMaxX - clippedMinX,
                        h = clippedMaxY - clippedMinY,
                    }
                    or nil,
            }
        end
    else
        -- No bbox available; degrade gracefully using the center screen.
        if centerScreen and centerScreen.x and centerScreen.y
           and centerScreen.x >= visibleRect.x and centerScreen.x < vrMaxX
           and centerScreen.y >= visibleRect.y and centerScreen.y < vrMaxY then
            anyCornerInside = true
        end
    end

    return {
        distance = distance,
        angleHorizontal = angleHorizontal,
        angleVertical = angleVertical,
        direction = direction,
        visible = anyCornerInside and lineOfSight,
        screen = centerScreen and {x = centerScreen.x, y = centerScreen.y} or nil,
        bbox = bboxOut,
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
