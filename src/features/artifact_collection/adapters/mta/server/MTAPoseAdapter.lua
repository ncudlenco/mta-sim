--- MTAPoseAdapter: server-side bridge for per-frame ped pose collection.
--- Requests bone-space pose data from one spectator's client (the spectator
--- here is just the client we use to read bones — bone world positions are
--- identical across clients for streamed-in peds). Results come back
--- asynchronously via `onPoseResponse`.
---
--- Follows the same single-pending-callback pattern as MTARenderModeController:
--- the spectator element identifies the channel, so only one request can be in
--- flight per spectator at a time. Collection is sequenced frame-by-frame by
--- ArtifactCollectionManager so that's already the case.
---
--- @classmod MTAPoseAdapter

MTAPoseAdapter = class(function(o, spectatorElement)
    o.name = "MTAPoseAdapter"
    if not spectatorElement or not isElement(spectatorElement) then
        error("[MTAPoseAdapter] Invalid spectator element")
    end

    o.spectator = spectatorElement
    o.pendingCallback = nil
    o.pendingRequestId = nil
    o.nextRequestId = 1
    o.eventHandlerRegistered = false

    o:_registerEventHandler()
end)

--- Register the server-side event handler for pose responses.
--- Bound to `self.spectator` so only responses from this client fire.
function MTAPoseAdapter:_registerEventHandler()
    if self.eventHandlerRegistered then
        return
    end

    local adapter = self

    addEvent("onPoseResponse", true)
    addEventHandler("onPoseResponse", self.spectator, function(requestId, poses, viewport)
        if adapter.pendingRequestId ~= requestId then
            if DEBUG then
                print(string.format("[MTAPoseAdapter] Dropping stale pose response: reqId=%s (expected=%s)",
                    tostring(requestId), tostring(adapter.pendingRequestId)))
            end
            return
        end

        local callback = adapter.pendingCallback
        adapter.pendingCallback = nil
        adapter.pendingRequestId = nil

        if callback then
            callback(true, poses, viewport)
        end
    end)

    self.eventHandlerRegistered = true
end

--- Request pose data for a list of peds.
--- @param pedElements table Array of MTA ped elements to query bones for
--- @param callback function Called with (success, poses) where poses is an
---                          array of {ped = pedElement, streamed = boolean,
---                          bones = {[jointIndex] = {x, y, z}}}
function MTAPoseAdapter:requestPoses(pedElements, callback)
    if not self.spectator or not isElement(self.spectator) then
        if callback then callback(false, nil) end
        return
    end

    if self.pendingCallback then
        if DEBUG then
            print("[MTAPoseAdapter] Overlapping pose request; previous callback discarded")
        end
        self.pendingCallback = nil
        self.pendingRequestId = nil
    end

    local requestId = self.nextRequestId
    self.nextRequestId = self.nextRequestId + 1

    self.pendingCallback = callback
    self.pendingRequestId = requestId

    triggerClientEvent(self.spectator, "onPoseRequest", self.spectator, requestId, pedElements)
end
