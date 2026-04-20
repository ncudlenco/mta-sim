--- ClientVisibilityHandler: occlusion check for a batch of elements using
--- GTA:SA's own raycast primitive.
---
--- For each requested element, `lineOfSight` is true if any probe point on the
--- element's bounding box (8 corners + center) is reachable by
--- `isLineOfSightClear` from the camera without crossing world geometry,
--- vehicles, peds, or objects. The element itself is excluded from the
--- raycast so its own mesh does not occlude.
---
--- Bounding-box corner probing — not just a single center raycast — keeps
--- partially-occluded entities (head poking out from behind a wall, arm out
--- from a doorway) correctly flagged as visible.
---
--- We deliberately do NOT call `isElementOnScreen`: it tests an element's
--- generous bounding sphere against an extended frustum and routinely returns
--- true for elements geometrically behind the camera. Frustum membership is
--- decided server-side from the camera matrix; this handler reports occlusion
--- only.
---

-- isLineOfSightClear flags we use for all probes (matches the recipe from
-- the project's visibility discussion): check buildings/vehicles/peds/objects,
-- NOT dummies, don't see through stuff, honour "ignoreSomeObjectsForCamera"
-- so GTA's camera-transparent props don't block us.
local LOS_CHECK_BUILDINGS = true
local LOS_CHECK_VEHICLES  = true
local LOS_CHECK_PEDS      = true
local LOS_CHECK_OBJECTS   = true
local LOS_CHECK_DUMMIES   = false
local LOS_SEE_THROUGH     = false
local LOS_IGNORE_CAMERA_OBJECTS = true

--- Rotate an object-space offset by an element's Euler angles (ZXY order,
--- the GTA:SA standard). Returns world-space delta from the element origin.
local function rotateOffset(ox, oy, oz, rx, ry, rz)
    local rrx = math.rad(rx)
    local rry = math.rad(ry)
    local rrz = math.rad(rz)
    local cx, sx = math.cos(rrx), math.sin(rrx)
    local cy, sy = math.cos(rry), math.sin(rry)
    local cz, sz = math.cos(rrz), math.sin(rrz)

    -- Yaw (Z) then pitch (X) then roll (Y); matches getElementRotation default.
    local x1 = ox * cz - oy * sz
    local y1 = ox * sz + oy * cz
    local z1 = oz

    local y2 = y1 * cx - z1 * sx
    local z2 = y1 * sx + z1 * cx
    local x2 = x1

    local x3 = x2 * cy + z2 * sy
    local z3 = -x2 * sy + z2 * cy
    local y3 = y2

    return x3, y3, z3
end

--- Compute the element's world-space axis-aligned bounding box transformed by
--- its rotation. Returns a table with `center` (average of the 8 rotated
--- corners) and `corners` (the 8 rotated corners), or nil if the element has
--- no bbox. The center is the authoritative "where is this thing visually"
--- point — much better than element.position, which is the DFF authoring
--- anchor and is arbitrary per model (wall-mount point for paintings,
--- base-centre for peds, etc.).
---
--- @param element userdata MTA element
--- @return table|nil {center = {x, y, z}, corners = {[1..8] = {x, y, z}}}
local function buildBboxWorld(element)
    local px, py, pz = getElementPosition(element)
    if not px then
        return nil
    end

    local xmin, ymin, zmin, xmax, ymax, zmax = getElementBoundingBox(element)
    if not xmin then
        return nil
    end

    local rx, ry, rz = getElementRotation(element)
    rx, ry, rz = rx or 0, ry or 0, rz or 0

    local localCorners = {
        {xmin, ymin, zmin}, {xmax, ymin, zmin},
        {xmin, ymax, zmin}, {xmax, ymax, zmin},
        {xmin, ymin, zmax}, {xmax, ymin, zmax},
        {xmin, ymax, zmax}, {xmax, ymax, zmax},
    }

    local corners = {}
    local cx, cy, cz = 0, 0, 0
    for i, c in ipairs(localCorners) do
        local dx, dy, dz = rotateOffset(c[1], c[2], c[3], rx, ry, rz)
        local wx, wy, wz = px + dx, py + dy, pz + dz
        corners[i] = {wx, wy, wz}
        cx = cx + wx
        cy = cy + wy
        cz = cz + wz
    end

    return {
        center  = {cx / 8, cy / 8, cz / 8},
        corners = corners,
    }
end

--- Build world-space probe points for the LOS raycast: element origin plus the
--- bbox center and 8 rotated corners (if a bbox is available). Element origin
--- is kept as the first probe so elements without a bbox still get a single
--- reasonable ray.
local function buildProbes(element, bboxWorld)
    local px, py, pz = getElementPosition(element)
    if not px then
        return nil
    end

    local probes = {{px, py, pz}}

    if bboxWorld then
        probes[#probes + 1] = bboxWorld.center
        for _, c in ipairs(bboxWorld.corners) do
            probes[#probes + 1] = c
        end
    end

    return probes
end

--- Run a line-of-sight probe from the camera to each point, returning true
--- as soon as one is clear. Element is excluded from occlusion checks.
local function anyProbeClear(probes, camX, camY, camZ, ignoredElement)
    for _, p in ipairs(probes) do
        if isLineOfSightClear(
            camX, camY, camZ, p[1], p[2], p[3],
            LOS_CHECK_BUILDINGS, LOS_CHECK_VEHICLES,
            LOS_CHECK_PEDS, LOS_CHECK_OBJECTS, LOS_CHECK_DUMMIES,
            LOS_SEE_THROUGH, LOS_IGNORE_CAMERA_OBJECTS, ignoredElement
        ) then
            return true
        end
    end
    return false
end

--- Project a world point to screen via the engine. Returns {x, y} or nil if
--- behind the camera / outside the render frustum.
local function projectToScreen(p)
    local sx, sy = getScreenFromWorldPosition(p[1], p[2], p[3], 0, false)
    if sx and sy then
        return {x = sx, y = sy}
    end
    return nil
end

addEvent("onVisibilityRequest", true)
addEventHandler("onVisibilityRequest", root, function(requestId, elements)
    local results = {}
    local viewportW, viewportH = guiGetScreenSize()

    if type(elements) ~= "table" then
        triggerServerEvent("onVisibilityResponse", localPlayer, requestId, results, {w = viewportW, h = viewportH})
        return
    end

    local camX, camY, camZ = getCameraMatrix()

    for i, element in ipairs(elements) do
        local entry = {lineOfSight = false, bbox = nil}

        if isElement(element) then
            local bboxWorld = buildBboxWorld(element)
            if bboxWorld then
                -- Attach engine-accurate 2D projection to the bbox so the
                -- server doesn't need to re-project world coords. Corners that
                -- project behind the camera come back as nil; the server's
                -- "any corner inside visibleRect" test handles that case.
                local centerScreen = projectToScreen(bboxWorld.center)
                local cornersScreen = {}
                for ci, corner in ipairs(bboxWorld.corners) do
                    cornersScreen[ci] = projectToScreen(corner)
                end
                bboxWorld.centerScreen = centerScreen
                bboxWorld.cornersScreen = cornersScreen
            end
            entry.bbox = bboxWorld

            local probes = buildProbes(element, bboxWorld)
            if probes and camX then
                entry.lineOfSight = anyProbeClear(probes, camX, camY, camZ, element)
            end
        end

        results[i] = entry
    end

    triggerServerEvent("onVisibilityResponse", localPlayer, requestId, results, {w = viewportW, h = viewportH})
end)
