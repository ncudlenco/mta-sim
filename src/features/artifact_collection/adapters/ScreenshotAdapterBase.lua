--- ScreenshotAdapterBase: Base class for screenshot capture adapters
-- Provides common functionality for managing pending screenshots
-- Subclasses implement game-specific screenshot capture mechanisms
--
-- @classmod ScreenshotAdapterBase
-- @author Claude Code
-- @license MIT

ScreenshotAdapterBase = class(function(o)
    o.name = "ScreenshotAdapterBase"
    o.pendingScreenshots = {} -- Indexed by tag
    o.eventHandlerRegistered = false
end)

--- Get count of pending screenshots
-- @return number Count of pending screenshots
function ScreenshotAdapterBase:getPendingCount()
    local count = 0
    for _ in pairs(self.pendingScreenshots) do
        count = count + 1
    end
    return count
end

--- Store a pending screenshot with its callback
-- @param tag string Unique tag for the screenshot
-- @param callback function Callback to invoke when complete
function ScreenshotAdapterBase:_storePending(tag, callback)
    self.pendingScreenshots[tag] = {
        callback = callback,
        timestamp = getTickCount and getTickCount() or 0,
    }
end

--- Retrieve and remove a pending screenshot
-- @param tag string The screenshot tag
-- @return table|nil The pending screenshot data, or nil if not found
function ScreenshotAdapterBase:_retrievePending(tag)
    local pending = self.pendingScreenshots[tag]
    if pending then
        self.pendingScreenshots[tag] = nil
    end
    return pending
end

--- Capture a screenshot
-- Must be implemented by subclasses
--
-- @param tag string Unique tag to identify this screenshot
-- @param width number Screenshot width
-- @param height number Screenshot height
-- @param filePath string File path where screenshot should be saved (for client-side)
-- @param callback function Called when capture completes: callback(success, pixels)
-- @return boolean True if capture was triggered successfully
function ScreenshotAdapterBase:captureScreenshot(tag, width, height, filePath, callback)
    error(string.format("%s:captureScreenshot() must be implemented by subclass", self.name))
end

--- Register event handlers for screenshot completion
-- Must be implemented by subclasses
function ScreenshotAdapterBase:registerEventHandler()
    error(string.format("%s:registerEventHandler() must be implemented by subclass", self.name))
end
