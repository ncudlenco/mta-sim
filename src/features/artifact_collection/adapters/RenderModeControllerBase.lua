--- RenderModeControllerBase: Abstract base class for client-side render mode control
--- Provides interface for controlling client rendering modes (segmentation, depth shaders)
--- Game-specific implementations handle event triggering and state management
---
--- @classmod RenderModeControllerBase
--- @author Claude Code
--- @license MIT

RenderModeControllerBase = class(function(o)
    o.name = "RenderModeControllerBase"
    o.currentMode = "normal"  -- "normal", "segmentation", "depth"
end)

--- Enable segmentation rendering mode on client
--- Triggers client-side shader and waits for ready confirmation
---
--- @param callback function Called when segmentation mode is active: callback(success)
function RenderModeControllerBase:enableSegmentation(callback)
    error(string.format("%s:enableSegmentation() must be implemented by subclass", self.name))
end

--- Disable segmentation rendering mode on client
--- Restores normal rendering
function RenderModeControllerBase:disableSegmentation()
    error(string.format("%s:disableSegmentation() must be implemented by subclass", self.name))
end

--- Enable depth rendering mode on client
--- Triggers client-side shader and waits for ready confirmation
---
--- @param callback function Called when depth mode is active: callback(success)
function RenderModeControllerBase:enableDepth(callback)
    error(string.format("%s:enableDepth() must be implemented by subclass", self.name))
end

--- Disable depth rendering mode on client
--- Restores normal rendering
function RenderModeControllerBase:disableDepth()
    error(string.format("%s:disableDepth() must be implemented by subclass", self.name))
end

--- Get current rendering mode
--- @return string Current mode ("normal", "segmentation", "depth")
function RenderModeControllerBase:getCurrentMode()
    return self.currentMode
end

--- Check if in normal rendering mode
--- @return boolean True if in normal mode
function RenderModeControllerBase:isNormalMode()
    return self.currentMode == "normal"
end
