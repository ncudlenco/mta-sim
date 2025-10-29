--- EventBus: Singleton event bus for publish-subscribe pattern
--- Enables loose coupling between components through event-driven communication
---
--- @class EventBus
--- @field instance EventBus Singleton instance
--- @field subscribers table Event subscriptions {eventType: {subscriberId: callback}}
--- @usage
---   local bus = EventBus:getInstance()
---   bus:subscribe("my_event", "my_component", function(data) print(data.message) end)
---   bus:publish("my_event", {message = "Hello"})
---
--- @author Claude Code
--- @license MIT

EventBus = {
    instance = nil
}

--- Get singleton instance of EventBus
--- Creates instance on first call, returns existing instance on subsequent calls
--- @return EventBus The singleton instance
function EventBus:getInstance()
    if not self.instance then
        self.instance = {
            subscribers = {}
        }
        setmetatable(self.instance, { __index = self })
    end
    return self.instance
end

--- Subscribe to an event type
--- Registers a callback function to be invoked when the specified event is published
---
--- @param eventType string The event type to subscribe to (e.g., "graph_event_start")
--- @param subscriberId string Unique identifier for this subscriber (e.g., "camera_handler")
--- @param callback function Callback function(eventData) to invoke when event is published
--- @usage bus:subscribe("graph_event_start", "camera_handler", function(data) ... end)
function EventBus:subscribe(eventType, subscriberId, callback)
    if not self.subscribers[eventType] then
        self.subscribers[eventType] = {}
    end
    self.subscribers[eventType][subscriberId] = callback

    if DEBUG then
        print("[EventBus] Subscribed: "..subscriberId.." to "..eventType)
    end
end

--- Unsubscribe from an event type
--- Removes the subscriber's callback for the specified event type
---
--- @param eventType string The event type to unsubscribe from
--- @param subscriberId string The subscriber identifier to remove
--- @usage bus:unsubscribe("graph_event_start", "camera_handler")
function EventBus:unsubscribe(eventType, subscriberId)
    if self.subscribers[eventType] then
        self.subscribers[eventType][subscriberId] = nil
    end
end

--- Publish an event to all subscribers
--- Invokes all registered callbacks for the specified event type with the provided data
--- Errors in individual callbacks are caught and logged without affecting other subscribers
---
--- @param eventType string The event type to publish (e.g., "graph_event_start")
--- @param eventData table Event data payload passed to all subscribers
--- @usage bus:publish("graph_event_start", {eventId = "m1", actorId = "alice", actionName = "SitDown"})
function EventBus:publish(eventType, eventData)
    if not self.subscribers[eventType] then
        return
    end

    if DEBUG then
        print("[EventBus] Publishing: "..eventType.." with data: "..stringifyTable(eventData))
    end

    for subscriberId, callback in pairs(self.subscribers[eventType]) do
        local success, err = pcall(callback, eventData)
        if not success then
            print("[EventBus] Error in subscriber "..subscriberId..": "..tostring(err))
        end
    end
end

--- Clear all subscriptions
--- Removes all subscribers from all event types
--- Typically called during story cleanup/reset
---
--- @usage bus:clear()
function EventBus:clear()
    self.subscribers = {}
    if DEBUG then
        print("[EventBus] Cleared all subscriptions")
    end
end
