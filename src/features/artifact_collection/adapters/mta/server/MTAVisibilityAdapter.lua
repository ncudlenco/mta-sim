--- MTAVisibilityAdapter: server-side bridge for per-element visibility checks.
--- Requests `isElementOnScreen` (frustum) + `isLineOfSightClear` (occlusion)
--- results for a batch of elements from one spectator's client. Results come
--- back asynchronously via `onVisibilityResponse`.
---
--- Mirrors MTAPoseAdapter's request-ID pattern so stale responses from a
--- previous frame (e.g. after an overlapping request) are dropped.
---
--- @classmod MTAVisibilityAdapter

MTAVisibilityAdapter = class(function(o, spectatorElement)
    o.name = "MTAVisibilityAdapter"
    if not spectatorElement or not isElement(spectatorElement) then
        error("[MTAVisibilityAdapter] Invalid spectator element")
    end

    o.spectator = spectatorElement
    o.pendingCallback = nil
    o.pendingRequestId = nil
    o.nextRequestId = 1
    o.eventHandlerRegistered = false

    o:_registerEventHandler()
end)

function MTAVisibilityAdapter:_registerEventHandler()
    if self.eventHandlerRegistered then
        return
    end

    local adapter = self

    addEvent("onVisibilityResponse", true)
    addEventHandler("onVisibilityResponse", self.spectator, function(requestId, results, viewport)
        if adapter.pendingRequestId ~= requestId then
            if DEBUG then
                print(string.format("[MTAVisibilityAdapter] Dropping stale response: reqId=%s (expected=%s)",
                    tostring(requestId), tostring(adapter.pendingRequestId)))
            end
            return
        end

        local callback = adapter.pendingCallback
        adapter.pendingCallback = nil
        adapter.pendingRequestId = nil

        if callback then
            callback(true, results, viewport)
        end
    end)

    self.eventHandlerRegistered = true
end

--- Request visibility data for a list of elements.
--- @param elements table Array of MTA elements to query visibility for
--- @param callback function Called with (success, results) where results is an
---                          array of {onScreen = bool, lineOfSight = bool}
---                          aligned with the input order
function MTAVisibilityAdapter:requestVisibility(elements, callback)
    if not self.spectator or not isElement(self.spectator) then
        if callback then callback(false, nil) end
        return
    end

    if self.pendingCallback then
        if DEBUG then
            print("[MTAVisibilityAdapter] Overlapping visibility request; previous callback discarded")
        end
        self.pendingCallback = nil
        self.pendingRequestId = nil
    end

    local requestId = self.nextRequestId
    self.nextRequestId = self.nextRequestId + 1

    self.pendingCallback = callback
    self.pendingRequestId = requestId

    triggerClientEvent(self.spectator, "onVisibilityRequest", self.spectator, requestId, elements)
end
