--- MTASimulationFreezeAdapter: MTA-specific simulation freeze/unfreeze
-- Handles pausing and resuming the game simulation using MTA's APIs
--
-- @classmod MTASimulationFreezeAdapter
-- @author Claude Code
-- @license MIT

MTASimulationFreezeAdapter = class(SimulationFreezeAdapterBase, function(o)
    SimulationFreezeAdapterBase.init(o)
    o.name = "MTASimulationFreezeAdapter"
end)

--- MTA-specific freeze implementation
-- Uses setGameSpeed(0) to freeze all animations, physics, weather, etc.
-- Also pauses all timers except excluded ones (artifact collection)
--
-- @return boolean Success status
function MTASimulationFreezeAdapter:_doFreeze()
    -- Store current game speed
    self.previousGameSpeed = getGameSpeed() or 1

    -- Pause all timers except excluded ones
    local allTimers = getTimers()
    local pausedCount = 0
    local excludedCount = 0

    for _, timer in ipairs(allTimers) do
        if self.excludedTimers[timer] then
            excludedCount = excludedCount + 1
        else
            setTimerPaused(timer, true)
            pausedCount = pausedCount + 1
        end
    end

    -- Freeze the game world
    setGameSpeed(0)

    if DEBUG then
        print(string.format("[MTASimulationFreezeAdapter] Frozen (gameSpeed: 0, timers paused: %d, excluded: %d)",
            pausedCount, excludedCount))
    end

    return true
end

--- MTA-specific unfreeze implementation
-- Restores game speed to previous value and resumes all paused timers
--
-- @return boolean Success status
function MTASimulationFreezeAdapter:_doUnfreeze()
    -- Resume all timers except excluded ones
    local allTimers = getTimers()
    local resumedCount = 0
    local excludedCount = 0

    for _, timer in ipairs(allTimers) do
        if self.excludedTimers[timer] then
            excludedCount = excludedCount + 1
        else
            setTimerPaused(timer, false)
            resumedCount = resumedCount + 1
        end
    end

    -- Restore game speed
    setGameSpeed(self.previousGameSpeed)

    if DEBUG then
        print(string.format("[MTASimulationFreezeAdapter] Unfrozen (gameSpeed: %.2f, timers resumed: %d, excluded: %d)",
            self.previousGameSpeed, resumedCount, excludedCount))
    end

    return true
end
