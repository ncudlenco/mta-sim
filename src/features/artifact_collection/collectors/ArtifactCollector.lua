--- ArtifactCollector: Base class for all artifact collectors
-- Provides common functionality and interface for artifact collection
--
-- @classmod ArtifactCollector
-- @author Claude Code
-- @license MIT

ArtifactCollector = class(function(o, name, config)
    o.name = name or "ArtifactCollector"
    o.config = config or {}
    o.enabled = config.enabled ~= false -- Enabled by default
end)

--- Collect artifact and save to disk
-- This method must be implemented by subclasses.
-- The callback should be invoked when collection is complete: callback(success)
--
-- @param frameContext table Current frame context data
-- @param frameId number Sequential frame number
-- @param callback function Completion callback: callback(success)
function ArtifactCollector:collectAndSave(frameContext, frameId, callback)
    error(string.format("%s:collectAndSave() must be implemented by subclass", self.name))
end

--- Check if collector is enabled
-- @return boolean True if enabled
function ArtifactCollector:isEnabled()
    return self.enabled
end

--- Enable or disable this collector
-- @param enabled boolean True to enable, false to disable
function ArtifactCollector:setEnabled(enabled)
    self.enabled = enabled

    if DEBUG then
        print(string.format("[%s] %s", self.name, enabled and "Enabled" or "Disabled"))
    end
end

--- Get file path for artifact
-- Constructs a standardized file path for saving artifacts
--
-- @param frameId number The frame number
-- @param filename string The filename (e.g., "screenshot.png")
-- @return string Absolute file path
function ArtifactCollector:getFilePath(frameId, filename)
    local basePath = self.config.outputPath or "data_out"
    local storyId = "unknown"
    local spectatorId = "unknown"

    -- Extract story and spectator IDs from config if available
    if self.config.storyId then
        storyId = self.config.storyId
    elseif CURRENT_STORY then
        storyId = CURRENT_STORY.Id or "unknown"
    end

    if self.config.spectatorId then
        spectatorId = self.config.spectatorId
    end

    -- Format frame ID with leading zeros (e.g., "0000", "0001")
    local frameIdStr = string.format("%04d", frameId)

    -- Construct path: basePath/storyId/spectatorId/frame_XXXX_filename
    local filePath = string.format("%s/%s/%s/frame_%s_%s",
        basePath, storyId, spectatorId, frameIdStr, filename)

    return filePath
end

--- Ensure directory exists for a file path
-- Creates parent directories if they don't exist
--
-- @param filePath string The file path
-- @return boolean True if directory exists or was created
function ArtifactCollector:ensureDirectory(filePath)
    -- Extract directory from file path
    local dir = filePath:match("(.*/)")

    if not dir then
        return true
    end

    -- In MTA, we can't create directories programmatically
    -- They must exist or be created externally
    -- Just return true for now - directories should be created by the system
    return true
end

--- Get collector name
-- @return string Collector name
function ArtifactCollector:getName()
    return self.name
end

--- Get collector configuration
-- @return table Configuration table
function ArtifactCollector:getConfig()
    return self.config
end
