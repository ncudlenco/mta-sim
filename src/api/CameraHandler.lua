--- Camera Handler Factory
--- Creates appropriate camera handler based on configuration mode
--- Supports two modes:
---   - "static": Automatic focus switching with 2-second timer (default, backward compatible)
---   - "cinematic": Graph-driven camera control using semantic commands
---
--- Usage:
---   local handler = CreateCameraHandler({mode = "cinematic"})
---   -- or --
---   local handler = CameraHandler()  -- defaults to static mode

--- Factory function to create appropriate camera handler based on configuration
--- @param cameraConfig table Optional configuration {mode = "static"|"cinematic", commands = table}
--- @return table CameraHandler instance (StaticCameraHandler or CinematicCameraHandler)
function CreateCameraHandler(cameraConfig)
    local mode = "static"  -- Default mode

    if cameraConfig and cameraConfig.mode then
        mode = cameraConfig.mode
    end

    if DEBUG then
        print("[CreateCameraHandler] Creating camera handler with mode: "..mode)
    end

    if mode == "cinematic" then
        return CinematicCameraHandler()
    else
        return StaticCameraHandler()
    end
end

--- Backward compatibility: CameraHandler as direct constructor (defaults to static mode)
--- This allows existing code that does CameraHandler() to continue working
--- without specifying any configuration
CameraHandler = CreateCameraHandler
