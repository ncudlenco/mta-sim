--- CoordSpaceWriter: writes a single `coord_space.json` file per
--- `(storyId, cameraId)` output directory describing the transform from the
--- canonical coordinate space used by collectors (pose, spatial relations)
--- to the saved-image pixel space produced by the native screenshot module.
---
--- The coord space chain is:
---
---   1. GTA viewport (client area of the MTA window)
---        size = viewport.w × viewport.h
---   2. Post-crop region (MTA watermark / overlays removed, OS chrome never
---      part of it)
---        origin = visibleRect.x, visibleRect.y (in viewport coords)
---        size   = visibleRect.w × visibleRect.h
---   3. Saved image (modality-specific resize of the post-crop region;
---      stretched resize, not letterboxed)
---        size = savedDims[modalityId].w × savedDims[modalityId].h
---
--- Server-side projection produces pixel coords in the viewport space (step 1).
--- A point is "actually rendered in the saved frame" iff its viewport pixel is
--- inside visibleRect (step 2) AND the client-side `isLineOfSightClear` raycast
--- is unobstructed.
---
--- Inverse transform for a viewport-space point `(x_vp, y_vp)` to saved-image
--- coords for modality `m`:
---
---   x_saved = (x_vp - visibleRect.x) * savedDims[m].w / visibleRect.w
---   y_saved = (y_vp - visibleRect.y) * savedDims[m].h / visibleRect.h
---
--- The JSON is written once per directory; subsequent calls for the same
--- (storyId, cameraId) are no-ops. Written on the first collection frame
--- where metadata is available.
---
--- @classmod CoordSpaceWriter

CoordSpaceWriter = class(function(o)
    o.name = "CoordSpaceWriter"
    o.writtenPaths = {}  -- [filePath] = true, so each path is written at most once
end)

--- Ensure coord_space.json exists in the `(storyId, cameraId)` directory.
--- No-op if already written or if metadata is unavailable.
---
--- @param storyId string Story identifier
--- @param cameraId string Camera / spectator identifier
--- @return boolean True if the file exists or was just written; false if metadata missing
function CoordSpaceWriter:ensureWritten(storyId, cameraId)
    if not storyId or not cameraId then
        return false
    end

    local filePath = self:_getFilePath(storyId, cameraId)
    if not filePath or self.writtenPaths[filePath] then
        return true
    end

    local meta = NativeCaptureMetadata.get()
    if not meta then
        return false  -- retry on a later frame
    end

    local payload = {
        schemaVersion = 1,
        storyId = storyId,
        cameraId = cameraId,
        viewport = meta.viewport,
        chrome = meta.chrome,
        cropInViewport = meta.cropInViewport,
        visibleRect = meta.visibleRect,
        savedDims = meta.savedDims,
        coordSpace = "viewport",
        notes = {
            "Collector screen.x/y values are in GTA viewport coords (origin = client-area top-left).",
            "A point is 'rendered in the saved frame' iff (x,y) is inside visibleRect AND lineOfSight was clear.",
            "Inverse transform to modality m saved-image: (x - visibleRect.x) * savedDims[m].w / visibleRect.w (same for y).",
            "Resize is stretched (aspect not preserved) so x and y scales may differ."
        }
    }

    local jsonStr = toJSON(payload, true)
    if not jsonStr then
        return false
    end

    local file = fileCreate(filePath)
    if not file then
        print(string.format("[CoordSpaceWriter] ERROR: could not create %s", filePath))
        return false
    end
    fileWrite(file, jsonStr)
    fileClose(file)

    self.writtenPaths[filePath] = true

    if DEBUG_SCREENSHOTS then
        print(string.format("[CoordSpaceWriter] Wrote %s", filePath))
    end

    return true
end

--- Build the coord_space.json path: `[LOAD_FROM_GRAPH]_out/[storyId]/[cameraId]/coord_space.json`
--- @param storyId string
--- @param cameraId string
--- @return string|nil Absolute file path, or nil if LOAD_FROM_GRAPH is unset
function CoordSpaceWriter:_getFilePath(storyId, cameraId)
    local graphPath = LOAD_FROM_GRAPH
    if not graphPath then
        return nil
    end
    if type(graphPath) == "table" then
        graphPath = graphPath[1]
        if not graphPath then
            return nil
        end
    end
    return string.format("%s_out/%s/%s/coord_space.json", graphPath, storyId, cameraId)
end
