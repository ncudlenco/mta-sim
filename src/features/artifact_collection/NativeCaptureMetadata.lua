--- NativeCaptureMetadata: Lua shim for the screenshot module's
--- `getNativeCaptureMetadata` binding. Caches the first successful result
--- (viewport, chrome, crop, visibleRect, savedDims are all stable for the
--- lifetime of a run once recording has started).
---
--- Returns nil when:
---   * The native module is not loaded (e.g. SCREENSHOT_COLLECTOR_TYPE ~= "native").
---   * The backend is not initialized yet.
---   * The viewport size is zero (no frame has been captured yet — cache miss,
---     caller should retry on a later frame).
---
--- Collectors should call `NativeCaptureMetadata.get()` on each collection
--- until it returns non-nil, then use the cached result for projection and
--- visibility decisions.
---
--- @module NativeCaptureMetadata

--- @table NativeCaptureMetadata
NativeCaptureMetadata = {}

local cached = nil
local clientViewport = nil  -- most recent {w, h} reported by a client handler

--- Return native capture metadata, or nil if not yet available.
--- The first non-nil result is cached and returned on subsequent calls.
---
--- When the native `getNativeCaptureMetadata` binding isn't present (e.g. the
--- multimodal backend is in use and there's no Desktop Duplication chrome/
--- crop info to report), we synthesise an identity metadata record from the
--- client-reported viewport so CoordSpaceWriter can still write
--- coord_space.json and so Python overlays have a consistent contract.
---
--- @return table|nil Metadata table: {viewport, chrome, cropInViewport, visibleRect, savedDims}
function NativeCaptureMetadata.get()
    if cached then
        return cached
    end

    if getNativeCaptureMetadata then
        local meta = getNativeCaptureMetadata()
        if meta and meta.viewport and meta.visibleRect
           and (meta.viewport.w or 0) > 0 and (meta.viewport.h or 0) > 0 then
            cached = meta
            if DEBUG_SCREENSHOTS then
                print(string.format(
                    "[NativeCaptureMetadata] Native: viewport=%dx%d, visibleRect=(%d,%d %dx%d)",
                    meta.viewport.w, meta.viewport.h,
                    meta.visibleRect.x, meta.visibleRect.y, meta.visibleRect.w, meta.visibleRect.h))
            end
            return cached
        end
    end

    -- Fallback: use the client-reported viewport to synthesise an identity
    -- transform. This covers the multimodal path where the saved image IS
    -- the viewport — no chrome, no crop, no resize.
    if clientViewport and (clientViewport.w or 0) > 0 and (clientViewport.h or 0) > 0 then
        local w, h = clientViewport.w, clientViewport.h
        cached = {
            viewport       = {w = w, h = h},
            chrome         = {left = 0, top = 0, right = 0, bottom = 0},
            cropInViewport = {left = 0, top = 0, right = 0, bottom = 0},
            visibleRect    = {x = 0, y = 0, w = w, h = h},
            savedDims      = {[0] = {w = w, h = h},
                              [1] = {w = w, h = h},
                              [2] = {w = w, h = h}},
        }
        if DEBUG_SCREENSHOTS then
            print(string.format("[NativeCaptureMetadata] Synthesised identity from client viewport=%dx%d", w, h))
        end
        return cached
    end

    return nil
end

--- Record the viewport reported by the latest client handler response.
--- Collectors call this on every successful client round-trip so the fallback
--- path stays fresh even if the client is resized mid-run.
---
--- @param viewport table|nil {w, h}
function NativeCaptureMetadata.setClientViewport(viewport)
    if not viewport or not viewport.w or not viewport.h then
        return
    end
    if clientViewport and clientViewport.w == viewport.w and clientViewport.h == viewport.h then
        return
    end
    clientViewport = {w = viewport.w, h = viewport.h}
    -- If nothing authoritative is cached yet, let the next get() resynthesise.
    -- A client-sourced record should not override a genuine native metadata.
    if cached and not cached.chrome then
        cached = nil
    end
end

--- Invalidate the cache so the next `get()` call re-queries the native module.
--- Use only when the backend has been re-initialized mid-run (rare).
function NativeCaptureMetadata.invalidate()
    cached = nil
end
