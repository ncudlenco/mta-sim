--- PoseCollector: captures per-frame 3D bone world positions and 2D screen
--- projections for every story actor visible from the spectator camera.
---
--- Bone reads happen on the client (getPedBonePosition is client-only); the
--- round-trip is managed by MTAPoseAdapter. Screen-space projection also
--- happens on the client via getScreenFromWorldPosition (engine-accurate,
--- aspect/FOV-correct), and the server reads screen coords straight off the
--- response — no server-side projection math.
---
--- Output structure (one JSON file per captured frame):
---   {
---     "frameId": 42,
---     "storyId": "story_abc",
---     "cameraId": "spectator_0",
---     "camera": {position, lookAt, fov, roll},
---     "resolution": {width, height},
---     "poses": [
---       {
---         "storyActorId": "a0",
---         "streamed": true,
---         "onScreen": true,
---         "bones": [
---           {"name": "head", "world": {x,y,z}, "screen": {x, y, depth, onScreen}},
---           ... (20 entries, aligned with the joint table)
---         ]
---       }
---     ]
---   }
---
--- @classmod PoseCollector

-- Joint schema (name + server-side documentation only — bone IDs live on the
-- client in ClientPoseHandler.lua). Order must match POSE_JOINTS there.
local POSE_JOINT_NAMES = {
    "head", "neck", "spine", "pelvis",
    "left_clavicle", "right_clavicle",
    "left_shoulder", "right_shoulder",
    "left_elbow", "right_elbow",
    "left_hand", "right_hand",
    "left_hip", "right_hip",
    "left_knee", "right_knee",
    "left_ankle", "right_ankle",
    "left_foot", "right_foot",
}

PoseCollector = class(ArtifactCollector, function(o, poseAdapter, coordSpaceWriter, config)
    ArtifactCollector.init(o, "PoseCollector", config)

    if not poseAdapter then
        error("[PoseCollector] Pose adapter is required")
    end

    o.poseAdapter = poseAdapter
    o.coordSpaceWriter = coordSpaceWriter  -- may be nil (graceful)
    o.cameraId = config.cameraId or "unknown"
    o.framesPerSecond = config.framesPerSecond or 30
    o.poseFPS = config.poseFPS or 0
    o.fallbackScreenWidth = config.screenWidth or WIDTH_RESOLUTION or 1920
    o.fallbackScreenHeight = config.screenHeight or HEIGHT_RESOLUTION or 1080
    o.includeOffscreen = config.includeOffscreen or false

    o.captureInterval = 1
    if o.poseFPS > 0 and o.poseFPS < o.framesPerSecond then
        o.captureInterval = math.floor(o.framesPerSecond / o.poseFPS)
    end

    o.frameCounter = 0
end)

--- Main collection method.
--- Asynchronous: the client round-trip completes in a future tick, at which
--- point we project bones to 2D and write the JSON.
function PoseCollector:collectAndSave(frameContext, frameId, callback)
    self.frameCounter = self.frameCounter + 1

    if self.captureInterval > 1 and (self.frameCounter % self.captureInterval ~= 0) then
        if callback then callback(true, 0, 0) end
        return
    end

    local camera = self:_getCameraMatrix()
    if not camera then
        if callback then callback(false, 0, 0) end
        return
    end

    local actorEntries = self:_enumerateStoryActors()
    if #actorEntries == 0 then
        if callback then callback(true, 0, 0) end
        return
    end

    local pedElements = {}
    for i, entry in ipairs(actorEntries) do
        pedElements[i] = entry.ped
    end

    self.poseAdapter:requestPoses(pedElements, function(success, poses, clientViewport)
        if not success or not poses then
            if callback then callback(false, 0, 0) end
            return
        end

        -- The client now projects every bone via `getScreenFromWorldPosition`
        -- and tells us which viewport it used. That becomes the authoritative
        -- coord system for the JSON, and CoordSpaceWriter can use it for the
        -- coord_space.json fallback when the native backend doesn't speak up.
        local viewportW, viewportH, visibleRect = self:_resolveViewport(clientViewport)

        if self.coordSpaceWriter and frameContext.storyId then
            NativeCaptureMetadata.setClientViewport(clientViewport)
            self.coordSpaceWriter:ensureWritten(frameContext.storyId, self.cameraId)
        end

        local outputData = self:_buildOutput(camera, viewportW, viewportH, visibleRect,
                                              actorEntries, poses, frameContext, frameId)
        local writeSuccess = self:_writeToFile(outputData, frameId, frameContext.storyId)

        if callback then callback(writeSuccess, 0, 0) end
    end)
end

--- Resolve viewport dims + visibleRect.
--- Priority: native backend metadata (Desktop Duplication chrome + crop info) >
--- client-supplied viewport (no crop, identity) > static fallback.
function PoseCollector:_resolveViewport(clientViewport)
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

--- Enumerate story actors (peds with a storyActorId set on element data).
--- @return table Array of {ped = pedElement, storyActorId = string}
function PoseCollector:_enumerateStoryActors()
    local entries = {}

    if not CURRENT_STORY or not CURRENT_STORY.CurrentEpisode then
        return entries
    end

    for _, ped in ipairs(CURRENT_STORY.CurrentEpisode.peds or {}) do
        if isElement(ped) then
            local storyActorId = ped:getData('id')
            if storyActorId then
                table.insert(entries, {ped = ped, storyActorId = storyActorId})
            end
        end
    end

    return entries
end

--- Get camera matrix from the spectator that matches this collector's cameraId.
function PoseCollector:_getCameraMatrix()
    if not CURRENT_STORY or not CURRENT_STORY.Spectators then
        return nil
    end

    local spectator = FirstOrDefault(CURRENT_STORY.Spectators, function(spec)
        return spec:getData('id') == self.cameraId
    end)

    if not spectator then
        return nil
    end

    local x, y, z, lx, ly, lz = spectator:getCameraMatrix()
    return {
        x = x, y = y, z = z,
        lx = lx, ly = ly, lz = lz,
        roll = spectator:getData('cameraRoll') or 0,
        fov = spectator:getData('cameraFOV') or 70
    }
end

--- Merge actor metadata with client bone data and project to 2D.
--- `visibleRect` is the post-crop region in viewport coords; a bone is marked
--- visible iff its projected pixel lies inside that rect AND the client's
--- line-of-sight raycast was clear. Bones projecting into the MTA watermark
--- zone (below visibleRect.y + visibleRect.h) are correctly flagged as
--- not visible.
function PoseCollector:_buildOutput(camera, viewportW, viewportH, visibleRect,
                                     actorEntries, poses, frameContext, frameId)
    local actorById = {}
    for _, entry in ipairs(actorEntries) do
        actorById[entry.ped] = entry.storyActorId
    end

    local outputPoses = {}
    local vrMaxX = visibleRect.x + visibleRect.w
    local vrMaxY = visibleRect.y + visibleRect.h

    for _, pose in ipairs(poses) do
        local storyActorId = actorById[pose.ped]
        if not storyActorId then
            -- Unknown ped — skip (could be a non-story ped if client enumerated extras).
        else
            -- Client projected each bone via getScreenFromWorldPosition; screenX/Y
            -- are nil when the bone is behind the camera. We no longer compute
            -- projection server-side.
            local bones = {}
            local anyBoneVisible = false
            for i = 1, #POSE_JOINT_NAMES do
                local b = pose.bones and pose.bones[i]
                if b then
                    local sx, sy = b.screenX, b.screenY
                    local inVisibleRect = (sx ~= nil) and (sy ~= nil)
                        and (sx >= visibleRect.x) and (sx < vrMaxX)
                        and (sy >= visibleRect.y) and (sy < vrMaxY)
                    local boneVisible = inVisibleRect and (b.lineOfSight == true)
                    bones[i] = {
                        name = POSE_JOINT_NAMES[i],
                        world = {x = b.x, y = b.y, z = b.z},
                        screen = {x = sx, y = sy},
                        visible = boneVisible
                    }
                    if boneVisible then
                        anyBoneVisible = true
                    end
                end
            end

            if self.includeOffscreen or anyBoneVisible then
                local actorPed = pose.ped
                table.insert(outputPoses, {
                    storyActorId = storyActorId,
                    streamed = pose.streamed,
                    visible = anyBoneVisible,
                    currentEventId = isElement(actorPed) and actorPed:getData('currentGraphEventId') or nil,
                    currentActionName = isElement(actorPed) and actorPed:getData('currentGraphActionName') or nil,
                    bones = bones
                })
            end
        end
    end

    return {
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
        poses = outputPoses
    }
end

--- Write JSON to [LOAD_FROM_GRAPH]_out/[storyId]/[cameraId]/frame_XXXX_pose.json
function PoseCollector:_writeToFile(data, frameId, storyId)
    if not LOAD_FROM_GRAPH then
        return false
    end

    local graphPath = LOAD_FROM_GRAPH
    if type(graphPath) == "table" then
        graphPath = graphPath[1] or "unknown"
    end

    local basePath = graphPath .. "_out"
    local storyPath = basePath .. "/" .. (storyId or "unknown")
    local cameraPath = storyPath .. "/" .. self.cameraId

    local frameIdStr = string.format("%04d", frameId)
    local filePath = cameraPath .. "/frame_" .. frameIdStr .. "_pose.json"

    local jsonStr = toJSON(data, true)
    if not jsonStr then return false end

    local file = fileCreate(filePath)
    if not file then return false end

    fileWrite(file, jsonStr)
    fileClose(file)
    return true
end
