--- ClientRenderModeController: Manages rendering modes (normal, segmentation, depth)
--- Responds to server events to switch rendering modes
--- Part of vertical architecture: adapters/mta/client/
---

local currentRenderMode = "normal"
local DEBUG_SCREENSHOTS = true
local storedShaders = nil         -- all shaders (cleanup list)
local storedMarkerDimensions = nil  -- Stores {[marker] = originalDimension}
local storedCoronaZTest = nil       -- Stores original corona z-test state
local colorFilterPatched = false    -- Tracks whether we patched the timecyc color filter

-- Depth-mode scoped state (mutually exclusive with segmentation; kept separate so
-- cleanup paths don't tangle and segmentation's extra world-state pinning stays
-- scoped to that mode).
local storedDepthShaders = nil
local storedDepthMarkerDimensions = nil
local storedDepthCoronaZTest = nil
local depthColorFilterPatched = false
local storedDepthLocalPlayerPosition = nil

-- Stored world-state snapshot (taken on segmentation enable, restored on disable).
-- Pinning these makes the pipeline's colour shift deterministic run-to-run so a
-- single calibration LUT can correct residuals.
local storedWorldState = nil
local storedLocalPlayerPosition = nil  -- Stores original localPlayer position during segmentation
local BEHIND_CAMERA_DISTANCE = 5       -- Distance behind camera to move player

-- Render-based synchronization: Wait for actual GPU render before notifying server
local pendingRenderConfirmation = nil  -- {mode: string, callback: function, frameMapping: table}
local renderConfirmationFrameCount = 0
local CONFIRMATION_FRAMES_REQUIRED = 4  -- Wait 4 rendered frames to ensure GPU has flushed


--- Check if texture name should be blacklisted (not segmented)
--- These are typically invisible elements (collision shapes, markers, coronas, shadows)
--- that become visible when shaders are applied
--- @param texName string Texture name to check
--- @return boolean True if texture should be excluded from segmentation
local function isBlacklisted(texName)
    if not texName then return true end

    local lower = string.lower(texName)

    -- Pattern-based prefixes (shadows, markers, coronas, etc.)
    local blacklistPrefixes = {
        "shad",        -- All shadow textures (shad_ped, shad_car, shad_exp, etc.)
        "shadow",      -- Shadow variants
        "marker",      -- All marker types
        "corona",      -- Corona effects (coronacircle, etc.)
        "smoke",       -- Smoke particles
        "flame",       -- Flame effects
        "particle",    -- Particle effects
        "arrow",       -- Arrow markers
        "water",       -- Water effects
        "checkpoint",  -- Checkpoint markers
        "cylinder",    -- Cylinder markers
        "ring",        -- Ring markers
        "colshape",     -- Collision shapes
    }

    for _, prefix in ipairs(blacklistPrefixes) do
        if string.find(lower, "^" .. prefix) then
            return true
        end
    end

    -- Exact matches for specific textures
    local blacklistExact = {
        "sphere",
        "colsphere",
        "waypoint",
        "cylinder",
        "ring",
        "arrow",
        "checkpoint",
        "cj_lightshade",  -- Volumetric light-through-blinds quads; appear as colored
                          -- rectangles with jagged edges overlaying real geometry.
    }

    for _, exact in ipairs(blacklistExact) do
        if lower == exact then
            return true
        end
    end

    return false
end

-- HLSL Shader for segmentation (inline)
-- Uses vertex + pixel shader to output solid color without any lighting/shadow influence
-- Explicitly disables lighting, fog, and blending to ensure deterministic colors
local SEGMENTATION_SHADER = [[
    // World transformation matrices
    float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;

    // Segmentation color parameter
    float4 gColor = float4(1, 1, 1, 1);

    // Vertex shader input/output structures
    struct VSInput
    {
        float4 Position : POSITION0;
    };

    struct VSOutput
    {
        float4 Position : POSITION0;
    };

    // Vertex shader - transform geometry without lighting calculations
    VSOutput SegmentationVS(VSInput input)
    {
        VSOutput output;
        output.Position = mul(input.Position, gWorldViewProjection);
        return output;
    }

    // Pixel shader - output solid color only, no lighting/shadow/fog applied
    float4 SegmentationPS(VSOutput input) : COLOR0
    {
        return gColor;
    }

    // Technique with explicit render states to disable all lighting effects
    technique segmentation
    {
        pass P0
        {
            // Disable all lighting and effects that could modify colors
            Lighting = FALSE;
            FogEnable = FALSE;
            AlphaBlendEnable = FALSE;
            AlphaTestEnable = FALSE;

            VertexShader = compile vs_2_0 SegmentationVS();
            PixelShader = compile ps_2_0 SegmentationPS();
        }
    }
]]

-- Kill shader: applied to textures we want hidden during segmentation (shadows,
-- coronas, particles, markers, lights, sun halos, etc.). Simply skipping these
-- textures is wrong: GTA still renders them with their normal colors on top of
-- our segmentation output (causing dark bands under peds, light glare, etc.).
-- This shader transforms geometry but writes no color and no depth, so the
-- underlying draw call becomes a no-op.
local KILL_SHADER = [[
    float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;

    struct VSInput  { float4 Position : POSITION0; };
    struct VSOutput { float4 Position : POSITION0; };

    VSOutput KillVS(VSInput input)
    {
        VSOutput output;
        output.Position = mul(input.Position, gWorldViewProjection);
        return output;
    }

    float4 KillPS(VSOutput input) : COLOR0
    {
        return float4(0, 0, 0, 0);
    }

    technique kill
    {
        pass P0
        {
            ColorWriteEnable = 0;
            ZWriteEnable = FALSE;
            AlphaBlendEnable = FALSE;
            AlphaTestEnable = FALSE;
            Lighting = FALSE;
            FogEnable = FALSE;

            VertexShader = compile vs_2_0 KillVS();
            PixelShader = compile ps_2_0 KillPS();
        }
    }
]]

-- Depth shader: writes linear eye-space Z as grayscale.
-- Per-pixel value is the fragment's distance from the camera projected onto the
-- view axis (i.e. perpendicular distance to the image plane, not radial 3D
-- distance). Encoding: saturate(viewZ / gMaxDepth) → 0 = at camera, 1 = at or
-- beyond gMaxDepth meters. Linear resolution, suitable as ML ground truth.
--
-- Derivation: for a standard perspective projection, clipPos.w equals eye-space Z.
-- We pass the full clipPos through TEXCOORD0 so the rasterizer does perspective-
-- correct interpolation on all components; the PS then reads the per-pixel
-- clipPos.w directly.
--
-- Structural choices driven by vs_2_0 hardware:
--   - clipPos is computed into a local, not read back from output.Position
--     (POSITION0 is write-only on SM2).
--   - The PS takes a separate input struct that omits POSITION0 — reading
--     POSITION from a PS is not valid in ps_2_0.
local DEPTH_SHADER = [[
    float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;
    float    gMaxDepth = 300.0;

    struct VSInput { float4 Position : POSITION0; };

    struct VSToPS
    {
        float4 Position : POSITION0;
        float4 ClipPos  : TEXCOORD0;
    };

    struct PSInput
    {
        float4 ClipPos : TEXCOORD0;
    };

    VSToPS DepthVS(VSInput input)
    {
        VSToPS output;
        float4 clipPos = mul(input.Position, gWorldViewProjection);
        output.Position = clipPos;
        output.ClipPos  = clipPos;
        return output;
    }

    float4 DepthPS(PSInput input) : COLOR0
    {
        float d = saturate(input.ClipPos.w / gMaxDepth);
        return float4(d, d, d, 1.0);
    }

    technique depth
    {
        pass P0
        {
            Lighting = FALSE;
            FogEnable = FALSE;
            AlphaBlendEnable = FALSE;
            AlphaTestEnable = FALSE;

            VertexShader = compile vs_2_0 DepthVS();
            PixelShader  = compile ps_2_0 DepthPS();
        }
    }
]]

-- Maximum encoded distance in meters. Fragments farther than this saturate to
-- white. Chosen to cover typical GTA SA playable range without wasting precision
-- on sky geometry.
local DEPTH_MAX_RANGE = 300.0

--- Convert HSV to RGB
--- @param h number Hue [0, 1]
--- @param s number Saturation [0, 1]
--- @param v number Value [0, 1]
--- @return number, number, number RGB values [0, 1]
local function hsvToRgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

--- Bitwise XOR for Lua 5.1 (MTA compatibility)
--- @param a number First operand
--- @param b number Second operand
--- @return number XOR result
local function bxor(a, b)
    local result = 0
    local bit = 1
    for i = 1, 32 do
        local a_bit = a % 2
        local b_bit = b % 2
        if a_bit ~= b_bit then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

--- Generate deterministic RGB color from texture name
--- Same texture name always produces the same color (across all simulation runs)
--- Uses FNV-1a hash with direct bit extraction for minimal collision probability
--- Collision probability: <0.01% for typical scenes (200-300 textures per frame)
--- @param texName string Texture name
--- @return number, number, number RGB values [0, 1]
local function textureNameToColor(texName)
    -- FNV-1a hash (deterministic, cross-simulation consistent)
    local FNV_OFFSET = 2166136261
    local FNV_PRIME = 16777619

    local hash = FNV_OFFSET
    for i = 1, #texName do
        local byte = string.byte(texName, i)
        hash = bxor(hash, byte)
        hash = (hash * FNV_PRIME) % 4294967296  -- Keep in 32-bit range
    end

    -- Extract independent byte ranges (no overlap, no multiplication artifacts)
    -- This provides maximum color space utilization
    local byte1 = hash % 256                      -- Bits 0-7   → Hue
    local byte2 = math.floor(hash / 256) % 256    -- Bits 8-15  → Saturation
    local byte3 = math.floor(hash / 65536) % 256  -- Bits 16-23 → Value

    -- Map directly to HSV (no golden ratio multiplication)
    -- Hue: full 360° spectrum with 256 distinct steps
    local hue = byte1 / 255.0

    -- Saturation: 0.85-1.0 range (vibrant colors only)
    local saturation = 0.85 + (byte2 / 255.0) * 0.15

    -- Value: 0.85-1.0 range (bright colors only)
    local value = 0.85 + (byte3 / 255.0) * 0.15

    -- Convert HSV to RGB
    return hsvToRgb(hue, saturation, value)
end

-- --- Force MTA to present current framebuffer to Desktop
-- --- This ensures Desktop Duplication API has a fresh frame to capture
-- --- Uses minimal invisible draw operation to trigger frame present
-- local function forceFramePresent()
--     dxDrawText("", 0, 0)
-- end

--- Calculate a position behind the camera (outside the field of view)
--- Uses camera matrix to determine view direction and positions player
--- directly behind the camera position
--- @return number, number, number x, y, z position behind camera
local function getPositionBehindCamera()
    local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()

    -- Calculate and normalize view direction
    local viewDirX = lookX - camX
    local viewDirY = lookY - camY
    local viewDirZ = lookZ - camZ
    local length = math.sqrt(viewDirX * viewDirX + viewDirY * viewDirY + viewDirZ * viewDirZ)
    if length > 0 then
        viewDirX = viewDirX / length
        viewDirY = viewDirY / length
        viewDirZ = viewDirZ / length
    end

    -- Position behind camera
    return camX - (viewDirX * BEHIND_CAMERA_DISTANCE),
           camY - (viewDirY * BEHIND_CAMERA_DISTANCE),
           camZ - (viewDirZ * BEHIND_CAMERA_DISTANCE)
end

--- Apply segmentation shader to all visible textures
--- Colors each texture with a unique, deterministic color based on texture name
local function applySegmentationShader()
    if DEBUG_SCREENSHOTS then
        outputDebugString("[ClientRenderModeController] Applying segmentation shader")
    end

    -- Phase 0A: Disable special effects that could affect colors
    -- Store original states for restoration later
    storedCoronaZTest = isWorldSpecialPropertyEnabled("coronaztest")

    -- Disable corona z-test (prevents corona effects from interfering)
    setWorldSpecialPropertyEnabled("coronaztest", false)

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientRenderModeController] Disabled coronas (was: %s)",
            tostring(storedCoronaZTest)))
    end

    -- Neutralize screen-space color grading so shader RGB survives to the framebuffer unchanged.
    -- Without this, GTA SA's color filter and grain pass shift low channels up and clamp highs,
    -- causing recorded mapping colors to diverge from captured pixels by up to ~60 RGB units.
    -- setColorFilter patches GTA's timecyc color-correction instructions to `mov eax, 0`
    -- for both passes; zero RGBA makes the blend a no-op. resetColorFilter restores the
    -- original dynamic bytes, so we use that on disable rather than re-patching with stale
    -- "current" values (which would freeze the game in a non-dynamic state).
    if setColorFilter then
        setColorFilter(0, 0, 0, 0, 0, 0, 0, 0)
        colorFilterPatched = true
    end

    -- Snapshot then pin world state so the GTA renderer's ambient/sun/weather
    -- contribution is identical every run. Residuals can then be corrected once
    -- via calibration instead of per-run. Restored in removeSegmentationShader.
    -- World properties patch GTA SA memory (addresses 0xB7C4A0+): setting them
    -- to zero removes the scene / object ambient and directional contributions
    -- that GTA's renderer adds on top of our shader output — the primary source
    -- of the residual +15..+35 shift observed after the color-filter disable.
    local function snapshotWorldProperty(name)
        if not getWorldProperty then return nil end
        return { getWorldProperty(name) }
    end

    storedWorldState = {
        time       = { getTime() },                                  -- {hour, minute}
        weather    = { getWeather() },                               -- {id, blendedId|nil}
        fog        = getFogDistance and getFogDistance() or nil,     -- number
        rain       = getRainLevel and getRainLevel() or nil,         -- number
        sun        = getSunColor and { getSunColor() } or nil,       -- {aR,aG,aB,bR,bG,bB}
        sky        = getSkyGradient and { getSkyGradient() } or nil, -- {tR,tG,tB,bR,bG,bB}
        ambient    = snapshotWorldProperty("AmbientColor"),          -- {r,g,b}
        ambientObj = snapshotWorldProperty("AmbientObjColor"),       -- {r,g,b}
        directional= snapshotWorldProperty("DirectionalColor"),      -- {r,g,b}
    }
    setTime(12, 0)
    setWeather(0)  -- EXTRASUNNY_LA, clear sky, minimal atmospheric tint
    if setFogDistance then setFogDistance(10000) end
    if setRainLevel  then setRainLevel(0) end
    if setSunColor   then setSunColor(255, 255, 255, 255, 255, 255) end
    if setSkyGradient then setSkyGradient(0, 0, 0, 0, 0, 0) end
    if setWorldProperty then
        setWorldProperty("AmbientColor",    0, 0, 0)
        setWorldProperty("AmbientObjColor", 0, 0, 0)
        setWorldProperty("DirectionalColor", 0, 0, 0)
    end
    -- Grain overlay has no getter; force to 0 during capture (default is also 0)
    if setGrainLevel then
        setGrainLevel(0)
    end

    -- Phase 0B: Temporarily move all markers to dimension 1 to hide them during segmentation
    -- Markers use world textures (coronastar, white, unnamed, etc.) which would otherwise be colored
    -- by our shaders. Moving to different dimension makes them invisible without affecting server-side data.
    storedMarkerDimensions = {}
    local markers = getElementsByType('marker', root, true)
    for _, marker in ipairs(markers) do
        local originalDim = getElementDimension(marker)
        storedMarkerDimensions[marker] = originalDim
        setElementDimension(marker, 1)  -- Move to dimension 1 (camera is in dimension 0)
    end

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientRenderModeController] Moved %d markers to dimension 1", #markers))
    end

    -- Phase 0C: Move localPlayer behind camera to hide from segmentation
    -- The spectator player is positioned in 3D space for interior streaming
    -- but becomes visible when segmentation shaders are applied
    storedLocalPlayerPosition = {
        x = localPlayer.position.x,
        y = localPlayer.position.y,
        z = localPlayer.position.z,
        interior = localPlayer.interior
    }

    local behindX, behindY, behindZ = getPositionBehindCamera()
    setElementPosition(localPlayer, behindX, behindY, behindZ)
    -- Interior unchanged to maintain streaming

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format(
            "[ClientRenderModeController] Moved localPlayer behind camera: (%.2f, %.2f, %.2f) -> (%.2f, %.2f, %.2f)",
            storedLocalPlayerPosition.x, storedLocalPlayerPosition.y, storedLocalPlayerPosition.z,
            behindX, behindY, behindZ))
    end

    -- Phase 1: Build texture→modelId mapping for visible dynamic elements
    local textureToModels = {}
    for _, elementType in ipairs({'object', 'vehicle', 'ped'}) do
        local elements = getElementsByType(elementType, root, true)
        for _, elem in ipairs(elements) do
            local type = getElementType(elem)
            if isElementOnScreen(elem) then
                local modelId = getElementModel(elem)
                local textures = engineGetModelTextureNames(modelId)

                if textures then
                    for _, texName in ipairs(textures) do
                        if not textureToModels[texName] then
                            textureToModels[texName] = {}
                        end

                        -- Add model info (avoid duplicates)
                        local found = false
                        for _, info in ipairs(textureToModels[texName]) do
                            if info.modelId == modelId and info.elementType == elementType then
                                found = true
                                break
                            end
                        end

                        if not found then
                            table.insert(textureToModels[texName], {
                                modelId = modelId,
                                elementType = elementType
                            })
                        end
                    end
                end
            end
        end
    end

    -- Phase 1.5: Build dynamic blacklist from unwanted element types
    -- These elements (markers, colshapes, lights, etc.) should not appear in segmentation
    local dynamicBlacklist = {}
    for _, unwantedType in ipairs({'marker', 'colshape', 'light', 'water', 'searchlight', 'weapon', 'effect'}) do
        local elements = getElementsByType(unwantedType, root, true)
        for _, elem in ipairs(elements) do
            if isElementOnScreen(elem) then
                local modelId = getElementModel(elem)
                if modelId then  -- Some elements might not have models
                    local textures = engineGetModelTextureNames(modelId)
                    if textures then
                        for _, texName in ipairs(textures) do
                            dynamicBlacklist[texName] = true
                            if DEBUG_SCREENSHOTS then
                                outputDebugString(string.format(
                                    "[ClientRenderModeController] Blacklisted %s texture: %s",
                                    unwantedType, texName))
                            end
                        end
                    end
                end
            end
        end
    end

    if DEBUG_SCREENSHOTS then
        local count = 0
        for _ in pairs(dynamicBlacklist) do count = count + 1 end
        outputDebugString(string.format("[ClientRenderModeController] Dynamically blacklisted %d textures", count))
    end

    -- Phase 2: Apply shaders to all visible textures (world textures)
    local visibleTextures = engineGetVisibleTextureNames()
    local frameMapping = {}
    local appliedShaders = {}

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientRenderModeController] Processing %d visible world textures",
            visibleTextures and #visibleTextures or 0))
    end

    local killCount = 0
    if visibleTextures then
        for _, texName in ipairs(visibleTextures) do
            if not isBlacklisted(texName) and not dynamicBlacklist[texName] then
                -- Colorize with segmentation shader (per-texture hash).
                local shader = dxCreateShader(SEGMENTATION_SHADER, 1.0, 0, false, "world,ped,vehicle,object")
                if shader then
                    local r, g, b = textureNameToColor(texName)
                    dxSetShaderValue(shader, 'gColor', {r, g, b, 1.0})
                    engineApplyShaderToWorldTexture(shader, texName)

                    frameMapping[texName] = {
                        color = {
                            math.floor(r * 255),
                            math.floor(g * 255),
                            math.floor(b * 255)
                        },
                        modelIds = textureToModels[texName] or {}
                    }

                    table.insert(appliedShaders, shader)
                elseif DEBUG_SCREENSHOTS then
                    outputDebugString("[ClientRenderModeController] Failed to create segmentation shader for: " .. texName)
                end
            else
                -- Hide with kill shader so shadow/corona/particle/light draws don't
                -- overlay the segmented scene with their native colors.
                local shader = dxCreateShader(KILL_SHADER, 2.0, 0, false, "world,ped,vehicle,object")
                if shader then
                    engineApplyShaderToWorldTexture(shader, texName)
                    table.insert(appliedShaders, shader)
                    killCount = killCount + 1
                elseif DEBUG_SCREENSHOTS then
                    outputDebugString("[ClientRenderModeController] Failed to create kill shader for: " .. texName)
                end
            end
        end
    end

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientRenderModeController] Applied %d kill shaders", killCount))
    end

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientRenderModeController] Total shaders applied: %d", #appliedShaders))
    end

    -- Store for cleanup
    storedShaders = appliedShaders
    currentRenderMode = "segmentation"

    -- Mute every MTA overlay stage (dxDraw queues, HUD, cursor, borderless
    -- tone-map) so the window-capture path sees only the shaded scene, not
    -- the post-composited frame. Required to get deterministic colours.
    if setCleanCaptureMode then
        setCleanCaptureMode(true)
    end

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format("[ClientRenderModeController] Applied %d shaders", #appliedShaders))
    end

    -- Shaders apply instantly to DirectX pipeline, but GPU needs time to render.
    -- Wait for render confirmation before notifying the server so Desktop
    -- Duplication sees the segmented frame, not a stale normal frame.
    pendingRenderConfirmation = {
        mode = "segmentation",
        frameMapping = frameMapping,
        callback = function(mapping)
            triggerServerEvent("onSegmentationReady", localPlayer, mapping)
        end
    }
    renderConfirmationFrameCount = 0

    if DEBUG_SCREENSHOTS then
        outputDebugString("[ClientRenderModeController] Waiting for render confirmation before notifying server...")
    end
end

--- Remove segmentation shader and restore normal rendering
local function removeSegmentationShader()
    if DEBUG_SCREENSHOTS then
        outputDebugString("[ClientRenderModeController] Removing segmentation shader")
    end

    -- Restore the overlay / tone-map pipeline first so subsequent frames
    -- render the HUD normally again.
    if setCleanCaptureMode then
        setCleanCaptureMode(false)
    end

    -- Destroy all created shaders
    if storedShaders then
        for _, shader in ipairs(storedShaders) do
            if isElement(shader) then
                destroyElement(shader)
            end
        end
        storedShaders = nil

        if DEBUG_SCREENSHOTS then
            outputDebugString("[ClientRenderModeController] Cleaned up all segmentation shaders")
        end
    end

    -- Note: localPlayer position is NOT restored - it stays behind camera
    -- This is intentional: player remains hidden and streaming continues to work

    -- Restore markers to their original dimensions
    -- Not needed as the markers are only there for pathfinding
    -- if storedMarkerDimensions then
    --     local count = 0
    --     for marker, originalDim in pairs(storedMarkerDimensions) do
    --         if isElement(marker) then
    --             setElementDimension(marker, originalDim)
    --             count = count + 1
    --         end
    --     end
    --     storedMarkerDimensions = nil

    --     if DEBUG_SCREENSHOTS then
    --         outputDebugString(string.format("[ClientRenderModeController] Restored %d markers to original dimensions", count))
    --     end
    -- end

    -- Restore special effects to original state
    if storedCoronaZTest ~= nil then
        setWorldSpecialPropertyEnabled("coronaztest", storedCoronaZTest)
        if DEBUG_SCREENSHOTS then
            outputDebugString(string.format("[ClientRenderModeController] Restored corona z-test to: %s", tostring(storedCoronaZTest)))
        end
        storedCoronaZTest = nil
    end

    -- Restore dynamic timecyc color filter (unpatches GTA's instruction bytes)
    if colorFilterPatched and resetColorFilter then
        resetColorFilter()
        colorFilterPatched = false
    end

    -- Restore pinned world state
    if storedWorldState then
        setTime(storedWorldState.time[1], storedWorldState.time[2])
        setWeather(storedWorldState.weather[1])
        if storedWorldState.fog and setFogDistance then
            setFogDistance(storedWorldState.fog)
        end
        if storedWorldState.rain and setRainLevel then
            setRainLevel(storedWorldState.rain)
        end
        if storedWorldState.sun and setSunColor then
            setSunColor(unpack(storedWorldState.sun))
        end
        if storedWorldState.sky and setSkyGradient then
            setSkyGradient(unpack(storedWorldState.sky))
        end
        if resetWorldProperty then
            resetWorldProperty("AmbientColor")
            resetWorldProperty("AmbientObjColor")
            resetWorldProperty("DirectionalColor")
        end
        storedWorldState = nil
    end

    currentRenderMode = "normal"

    -- Shaders removed instantly from DirectX pipeline, but GPU needs time to render
    -- Wait for render confirmation before notifying server
    -- This ensures Desktop Duplication API sees the normal frame, not a stale segmented frame
    pendingRenderConfirmation = {
        mode = "normal",
        frameMapping = nil,
        callback = function()
            triggerServerEvent("onSegmentationDisabled", localPlayer)
        end
    }
    renderConfirmationFrameCount = 0

    if DEBUG_SCREENSHOTS then
        outputDebugString("[ClientRenderModeController] Waiting for render confirmation before notifying server...")
    end
end

--- Apply depth shader to the whole scene.
--- Renders every world/ped/vehicle/object fragment as a grayscale encoding of
--- its linear eye-space distance from the camera. Particles/coronas/shadows/
--- markers are suppressed with KILL_SHADER so they don't overlay the depth
--- encoding with native colors. The color filter is patched to zero so the
--- grayscale output survives GTA's post-processing without tinting.
---
--- Disable path writes `onDepthReady` after 4 rendered frames using the same
--- render-confirmation mechanism as segmentation.
local function applyDepthShader()
    if DEBUG_SCREENSHOTS then
        outputDebugString("[ClientRenderModeController] Applying depth shader")
    end

    -- Snapshot and disable corona z-test so corona draws don't punch through depth.
    storedDepthCoronaZTest = isWorldSpecialPropertyEnabled("coronaztest")
    setWorldSpecialPropertyEnabled("coronaztest", false)

    -- Neutralize GTA's screen-space color grading (same reasoning as segmentation:
    -- the timecyc color filter otherwise shifts channels and clamps highs,
    -- corrupting the deterministic grayscale we emit).
    if setColorFilter then
        setColorFilter(0, 0, 0, 0, 0, 0, 0, 0)
        depthColorFilterPatched = true
    end

    -- Hide grain overlay (default is 0 but force just in case).
    if setGrainLevel then
        setGrainLevel(0)
    end

    -- Move markers to dimension 1 so their quads don't show up as flat gray.
    storedDepthMarkerDimensions = {}
    local markers = getElementsByType('marker', root, true)
    for _, marker in ipairs(markers) do
        storedDepthMarkerDimensions[marker] = getElementDimension(marker)
        setElementDimension(marker, 1)
    end

    -- Hide the spectator's ped by parking it behind the camera.
    storedDepthLocalPlayerPosition = {
        x = localPlayer.position.x,
        y = localPlayer.position.y,
        z = localPlayer.position.z,
        interior = localPlayer.interior
    }
    local behindX, behindY, behindZ = getPositionBehindCamera()
    setElementPosition(localPlayer, behindX, behindY, behindZ)

    local appliedShaders = {}
    local depthCount = 0
    local killCount = 0

    -- Iterate visible textures and apply per-texture (matching segmentation's
    -- approach). Using engineApplyShaderToWorldTexture with a "*" wildcard was
    -- unreliable — this form is the one we know works in this engine.
    local visibleTextures = engineGetVisibleTextureNames()
    if visibleTextures then
        for _, texName in ipairs(visibleTextures) do
            if isBlacklisted(texName) then
                local killShader = dxCreateShader(KILL_SHADER, 2.0, 0, false, "world,ped,vehicle,object")
                if killShader then
                    engineApplyShaderToWorldTexture(killShader, texName)
                    table.insert(appliedShaders, killShader)
                    killCount = killCount + 1
                end
            else
                local depthShader = dxCreateShader(DEPTH_SHADER, 1.0, 0, false, "world,ped,vehicle,object")
                if depthShader then
                    dxSetShaderValue(depthShader, 'gMaxDepth', DEPTH_MAX_RANGE)
                    engineApplyShaderToWorldTexture(depthShader, texName)
                    table.insert(appliedShaders, depthShader)
                    depthCount = depthCount + 1
                end
            end
        end
    end

    storedDepthShaders = appliedShaders
    currentRenderMode = "depth"

    -- Same reasoning as segmentation: suppress overlays/tone-map so the
    -- grayscale depth encoding survives to the window-capture path unchanged.
    if setCleanCaptureMode then
        setCleanCaptureMode(true)
    end

    if DEBUG_SCREENSHOTS then
        outputDebugString(string.format(
            "[ClientRenderModeController] Depth: %d depth + %d kill shaders applied",
            depthCount, killCount))
    end

    -- Wait for the GPU to render the depth-encoded frame before notifying server,
    -- matching segmentation's confirmation path so Desktop Duplication sees it.
    pendingRenderConfirmation = {
        mode = "depth",
        frameMapping = nil,
        callback = function()
            triggerServerEvent("onDepthReady", localPlayer)
        end
    }
    renderConfirmationFrameCount = 0
end

--- Remove depth shader and restore normal rendering.
--- Waits for N rendered frames via the same confirmation path as segmentation
--- so the subsequent raw capture doesn't still see depth-shaded fragments.
local function removeDepthShader()
    if DEBUG_SCREENSHOTS then
        outputDebugString("[ClientRenderModeController] Removing depth shader")
    end

    if setCleanCaptureMode then
        setCleanCaptureMode(false)
    end

    if storedDepthShaders then
        for _, shader in ipairs(storedDepthShaders) do
            if isElement(shader) then
                destroyElement(shader)
            end
        end
        storedDepthShaders = nil
    end

    if storedDepthCoronaZTest ~= nil then
        setWorldSpecialPropertyEnabled("coronaztest", storedDepthCoronaZTest)
        storedDepthCoronaZTest = nil
    end

    if depthColorFilterPatched and resetColorFilter then
        resetColorFilter()
        depthColorFilterPatched = false
    end

    -- Note: marker dimensions and localPlayer position are intentionally not
    -- restored — they follow segmentation's convention (markers are pathfinding-
    -- only, player staying behind camera keeps streaming working).
    storedDepthMarkerDimensions = nil
    storedDepthLocalPlayerPosition = nil

    currentRenderMode = "normal"

    pendingRenderConfirmation = {
        mode = "normal",
        frameMapping = nil,
        callback = function()
            triggerServerEvent("onDepthDisabled", localPlayer)
        end
    }
    renderConfirmationFrameCount = 0
end

--- Event: Toggle segmentation rendering
addEvent("onRenderSegmentation", true)
addEventHandler("onRenderSegmentation", root, function(enabled)
    if enabled then
        applySegmentationShader()
    else
        removeSegmentationShader()
    end
end)

--- Event: Toggle depth rendering
addEvent("onRenderDepth", true)
addEventHandler("onRenderDepth", root, function(enabled)
    if enabled then
        applyDepthShader()
    else
        removeDepthShader()
    end
end)

--- onClientRender: GPU render synchronization
--- Waits for N frames to be rendered before confirming shader state change to server
--- This ensures Desktop Duplication API sees the correct frame state
addEventHandler("onClientRender", root, function()
    if pendingRenderConfirmation then
        renderConfirmationFrameCount = renderConfirmationFrameCount + 1
        local required = pendingRenderConfirmation.framesRequired or CONFIRMATION_FRAMES_REQUIRED

        if renderConfirmationFrameCount >= required then
            local mode = pendingRenderConfirmation.mode
            local callback = pendingRenderConfirmation.callback
            local frameMapping = pendingRenderConfirmation.frameMapping

            -- Clear pending confirmation
            pendingRenderConfirmation = nil
            renderConfirmationFrameCount = 0

            if DEBUG_SCREENSHOTS then
                outputDebugString(string.format(
                    "[ClientRenderModeController] Render confirmation complete for mode: %s (waited %d frames)",
                    mode, CONFIRMATION_FRAMES_REQUIRED))
            end

            -- NOW it's safe to notify server - GPU has rendered the new state
            if callback then
                callback(frameMapping)
            end
        end
    end
end)

if DEBUG_SCREENSHOTS then
    outputDebugString("[ClientRenderModeController] Initialized")
end
