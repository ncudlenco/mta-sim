--- AdapterProviderBase: Abstract base class for game-specific adapter providers
--- Defines the interface that all adapter providers must implement
--- Each game (MTA, FiveM, etc.) provides its own concrete implementation
---
--- @classmod AdapterProviderBase
--- @license MIT

AdapterProviderBase = class(function(o)
    o.gameType = "unknown"
end)

--- Extract game-agnostic spectator data from game-specific entities
--- Converts game-specific spectator/player entities to normalized SpectatorData structure
---
--- @param spectators table Array of game-specific spectator/player entities
--- @return table Array of SpectatorData objects with {id, entity, gameType}
function AdapterProviderBase:extractSpectatorData(spectators)
    error(string.format("%s:extractSpectatorData() must be implemented by subclass", self.gameType))
end

--- Create game-specific simulation freeze adapter
--- Handles pausing/unpausing game simulation and timers
---
--- @return SimulationFreezeAdapterBase Freeze adapter instance
function AdapterProviderBase:createFreezeAdapter()
    error(string.format("%s:createFreezeAdapter() must be implemented by subclass", self.gameType))
end

--- Create game-specific client-side screenshot adapter
--- Handles triggering screenshot capture on client with zero network latency
---
--- @param spectatorData SpectatorData The spectator data containing entity reference
--- @return ScreenshotAdapterBase Screenshot adapter instance
function AdapterProviderBase:createClientScreenshotAdapter(spectatorData)
    error(string.format("%s:createClientScreenshotAdapter() must be implemented by subclass", self.gameType))
end

--- Create game-specific native screenshot adapter (singleton)
--- Handles native DLL-based screenshot capture for multi-modal video recording
---
--- @return ScreenshotAdapterBase Screenshot adapter instance (shared singleton)
function AdapterProviderBase:createNativeScreenshotAdapter()
    error(string.format("%s:createNativeScreenshotAdapter() must be implemented by subclass", self.gameType))
end

--- Create game-specific render mode controller
--- Handles client-side rendering mode changes (segmentation, depth shaders)
---
--- @param spectatorData SpectatorData The spectator data containing entity reference
--- @return RenderModeControllerBase Render mode controller instance
function AdapterProviderBase:createRenderModeController(spectatorData)
    error(string.format("%s:createRenderModeController() must be implemented by subclass", self.gameType))
end

--- Get the game type identifier
--- @return string Game type ("mta", "fivem", etc.)
function AdapterProviderBase:getGameType()
    return self.gameType
end
