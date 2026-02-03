--- SimulationFreezeAdapterBase: Base class for simulation freeze/unfreeze adapters
-- Provides common functionality for freezing and unfreezing game simulation
-- Subclasses implement game-specific freeze/unfreeze mechanisms
--
-- @classmod SimulationFreezeAdapterBase
-- @license MIT

SimulationFreezeAdapterBase = class(function(o)
    o.name = "SimulationFreezeAdapterBase"
    o.frozen = false
    o.previousGameSpeed = 1
    o.excludedTimers = {} -- Timers that should NOT be paused (artifact collection timers)
end)

--- Register a timer that should NOT be paused during freeze
-- This is used for artifact collection manager timers
-- @param timer Timer The timer to exclude from pausing
function SimulationFreezeAdapterBase:excludeTimer(timer)
    if timer and isTimer(timer) then
        self.excludedTimers[timer] = true
        if DEBUG then
            print(string.format("[%s] Timer excluded from pausing", self.name))
        end
    end
end

--- Remove a timer from the exclusion list
-- @param timer Timer The timer to stop excluding
function SimulationFreezeAdapterBase:removeExcludedTimer(timer)
    if timer then
        self.excludedTimers[timer] = nil
    end
end

--- Check if currently frozen
-- @return boolean True if frozen
function SimulationFreezeAdapterBase:isFrozen()
    return self.frozen
end

--- Freeze the simulation
-- Calls game-specific _doFreeze() implementation
--
-- @return boolean Success status
function SimulationFreezeAdapterBase:freeze()
    if self.frozen then
        if DEBUG then
            print(string.format("[%s] Already frozen", self.name))
        end
        return false
    end

    -- Call game-specific freeze implementation
    local success = self:_doFreeze()

    if success then
        self.frozen = true

        if DEBUG then
            print(string.format("[%s] Frozen successfully", self.name))
        end
    else
        if DEBUG then
            print(string.format("[%s] Failed to freeze", self.name))
        end
    end

    return success
end

--- Unfreeze the simulation
-- Calls game-specific _doUnfreeze() implementation
--
-- @return boolean Success status
function SimulationFreezeAdapterBase:unfreeze()
    if not self.frozen then
        if DEBUG then
            print(string.format("[%s] Not frozen", self.name))
        end
        return false
    end

    -- Call game-specific unfreeze implementation
    local success = self:_doUnfreeze()

    if success then
        self.frozen = false

        if DEBUG then
            print(string.format("[%s] Unfrozen successfully", self.name))
        end
    else
        if DEBUG then
            print(string.format("[%s] Failed to unfreeze", self.name))
        end
    end

    return success
end

--- Game-specific freeze implementation
-- Must be implemented by subclasses
--
-- @return boolean Success status
function SimulationFreezeAdapterBase:_doFreeze()
    error(string.format("%s:_doFreeze() must be implemented by subclass", self.name))
end

--- Game-specific unfreeze implementation
-- Must be implemented by subclasses
--
-- @return boolean Success status
function SimulationFreezeAdapterBase:_doUnfreeze()
    error(string.format("%s:_doUnfreeze() must be implemented by subclass", self.name))
end
