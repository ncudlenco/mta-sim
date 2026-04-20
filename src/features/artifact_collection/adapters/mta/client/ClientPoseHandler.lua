--- ClientPoseHandler: reads per-ped bone world positions on the client and
--- runs an occlusion raycast for each bone.
---
--- Responds to `onPoseRequest` by querying, for each requested ped:
---   * `getPedBonePosition` for each of the 20 joints (client-only API).
---   * `isLineOfSightClear(camera → bone, ignoredElement = ped)` per bone to
---     detect occlusion by world geometry, vehicles, other peds, or objects.
---     The ped itself is ignored so its own mesh doesn't block its own bones.
---
--- We deliberately do NOT call `isElementOnScreen`: it tests an element's
--- (often-generous) bounding sphere against an extended frustum and routinely
--- returns true for elements that are geometrically behind the camera. The
--- server projects each bone with its camera matrix to get authoritative
--- frustum membership, then ANDs that with our `lineOfSight` result.
---

local LOS_CHECK_BUILDINGS = true
local LOS_CHECK_VEHICLES  = true
local LOS_CHECK_PEDS      = true
local LOS_CHECK_OBJECTS   = true
local LOS_CHECK_DUMMIES   = false
local LOS_SEE_THROUGH     = false
local LOS_IGNORE_CAMERA_OBJECTS = true

-- Joint index → MTA ped-bone ID. The names mirror bone_attach_c.lua:31-50.
-- Kept in sync with that file; we intentionally duplicate the primary bone IDs
-- here so the pose pipeline does not depend on boneAttach state.
local POSE_JOINTS = {
    {name = "head",           bone = 5},
    {name = "neck",           bone = 4},
    {name = "spine",          bone = 3},
    {name = "pelvis",         bone = 1},
    {name = "left_clavicle",  bone = 4},
    {name = "right_clavicle", bone = 4},
    {name = "left_shoulder",  bone = 32},
    {name = "right_shoulder", bone = 22},
    {name = "left_elbow",     bone = 33},
    {name = "right_elbow",    bone = 23},
    {name = "left_hand",      bone = 34},
    {name = "right_hand",     bone = 24},
    {name = "left_hip",       bone = 41},
    {name = "right_hip",      bone = 51},
    {name = "left_knee",      bone = 42},
    {name = "right_knee",     bone = 52},
    {name = "left_ankle",     bone = 43},
    {name = "right_ankle",    bone = 53},
    {name = "left_foot",      bone = 44},
    {name = "right_foot",     bone = 54},
}

addEvent("onPoseRequest", true)
addEventHandler("onPoseRequest", root, function(requestId, pedElements)
    local poses = {}

    -- Viewport dims so the server knows what coordinate space the screen
    -- coords below are in. With `getScreenFromWorldPosition` (which uses the
    -- real camera matrix and MSAA'd render target), viewport == what the
    -- client renders at == what the saved frame captures, so server-side
    -- projection is no longer needed.
    local viewportW, viewportH = guiGetScreenSize()

    if type(pedElements) ~= "table" then
        triggerServerEvent("onPoseResponse", localPlayer, requestId, poses, {w = viewportW, h = viewportH})
        return
    end

    local camX, camY, camZ = getCameraMatrix()

    for _, ped in ipairs(pedElements) do
        if isElement(ped) and getElementType(ped) == "ped" then
            local streamed = isElementStreamedIn(ped)
            local bones = {}

            if streamed then
                for i, joint in ipairs(POSE_JOINTS) do
                    local x, y, z = getPedBonePosition(ped, joint.bone)
                    if x then
                        local lineOfSight = false
                        if camX then
                            lineOfSight = isLineOfSightClear(
                                camX, camY, camZ, x, y, z,
                                LOS_CHECK_BUILDINGS, LOS_CHECK_VEHICLES,
                                LOS_CHECK_PEDS, LOS_CHECK_OBJECTS, LOS_CHECK_DUMMIES,
                                LOS_SEE_THROUGH, LOS_IGNORE_CAMERA_OBJECTS, ped
                            ) == true
                        end
                        -- Engine-accurate 2D projection. Returns false (or nil)
                        -- when the bone is behind the camera — we pass that
                        -- through so the server can mark the keypoint invisible.
                        local sx, sy = getScreenFromWorldPosition(x, y, z, 0, false)
                        bones[i] = {
                            x = x, y = y, z = z,
                            screenX = sx or nil,
                            screenY = sy or nil,
                            lineOfSight = lineOfSight,
                        }
                    end
                end
            end

            table.insert(poses, {
                ped = ped,
                streamed = streamed,
                bones = bones
            })
        end
    end

    triggerServerEvent("onPoseResponse", localPlayer, requestId, poses, {w = viewportW, h = viewportH})
end)
