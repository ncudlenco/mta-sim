--- Wave action - makes a ped wave at an optional target or perform a general wave gesture
--- Supports both infinite looping mode (default) and finite wave sequence
--- @param params table Constructor parameters
--- @param params.Target userdata|table|nil Optional target to wave at (ped or object)
--- @param params.loop boolean|nil If true (default), waves indefinitely; if false, performs finite wave sequence
Wave = class(StoryActionBase, function(o, params)
    -- Build description based on target type
    local description = " waves"

    if params.Target then
        local targetType = isElement(params.Target) and params.Target:getType() or nil

        if targetType == "ped" or targetType == "player" then
            -- Target is an actor
            description = " waves at " .. params.Target:getData('name')
        elseif params.Target.Description then
            -- Target is an object
            description = " waves at the " .. params.Target.Description
        else
            description = " waves at something"
        end
    end

    params.description = description
    params.name = 'Wave'

    StoryActionBase.init(o, params)

    o.Target = params.Target
    o.loop = params.loop ~= nil and params.loop or false
end)

--- Gets the current target position (updated dynamically for moving targets)
--- @return Vector3|nil The current target position or nil if target is invalid
function Wave:GetTargetPosition()
    if self.Target then
        -- Check if target is still valid
        if not isElement(self.Target) or not self.Target.position then
            return self.TargetCoordinates  -- Fallback to static coordinates if available
        end

        local targetType = self.Target:getType()
        if targetType == "ped" or targetType == "player" or self.Target.position then
            return self.Target.position
        end
    elseif self.TargetCoordinates then
        return self.TargetCoordinates
    end
    return nil
end

--- Gets the target element if it's a ped or player
--- @return userdata|nil The target ped/player element or nil
function Wave:GetTargetElement()
    if self.Target and isElement(self.Target) then
        local targetType = self.Target:getType()
        if targetType == "ped" or targetType == "player" then
            return self.Target
        end
    end
    return nil
end

--- Apply the wave action with optional target rotation and loop/finite mode
function Wave:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    -- Determine log description with appropriate exit verbs for infinite mode
    local logDescription = self.Description
    local exitVerbs = nil

    if self.loop then
        exitVerbs = {"stops waving", "finishes waving"}
    end

    StoryActionBase.GetLogger(self, story):Log(logDescription, self, false, true, exitVerbs)

    -- Optionally rotate to face target before waving
    if self.Target and isElement(self.Target) and self.Target.position then
        LookingBehavior.faceTowardsTarget(self.Performer, self.Target.position)
    end

    if self.loop then
        -- Infinite loop mode: wave_in (setup) → wave_loop (indefinite)
        local setupTime = 5000

        self.rotationTimer = LookingBehavior.startContinuousLooking(
            self.Performer,
            function() return self:GetTargetPosition() end,
            {
                expectedAction = 'LookAt',
                updateInterval = 1000,
                skipBodyRotation = false,
                initialDelay = 500,
                getTargetElementFn = function() return self:GetTargetElement() end
            }
        )

        -- Start with wave_in animation
        self.Performer:setAnimation("ON_LOOKERS", "wave_in", setupTime, true, false, false, false)

        -- Transition to indefinite wave_loop after setup
        Timer(function()
            if self.Performer and isElement(self.Performer) then
                -- -1 time means loop indefinitely, freezeLastFrame=true preserves animation state
                self.Performer:setAnimation("ON_LOOKERS", "wave_loop", -1, true, false, false, false)
            end
        end, setupTime, 1)

        if DEBUG then
            outputConsole("Wave:Apply (infinite loop mode)")
        end

        -- Action is considered complete after setup, but animation continues
        OnGlobalActionFinished(setupTime, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
            LookingBehavior.stopContinuousLooking(self.rotationTimer)
        end)
    else
        -- Finite mode: wave_in → wave_loop (brief) → wave_out
        local waveInTime = 1500
        local waveLoopTime = 5000
        local waveOutTime = 1000
        local totalDuration = waveInTime + waveLoopTime + waveOutTime

        self.rotationTimer = LookingBehavior.startContinuousLooking(
            self.Performer,
            function() return self:GetTargetPosition() end,
            {
                expectedAction = 'LookAt',
                updateInterval = 1000,
                skipBodyRotation = false,
                initialDelay = 500,
                getTargetElementFn = function() return self:GetTargetElement() end
            }
        )

        -- Step 1: wave_in
        self.Performer:setAnimation("ON_LOOKERS", "wave_in", waveInTime, false, false, false, false)

        -- Step 2: wave_loop (brief)
        Timer(function()
            if self.Performer and isElement(self.Performer) then
                self.Performer:setAnimation("ON_LOOKERS", "wave_loop", waveLoopTime, false, false, false, false)
            end
        end, waveInTime, 1)

        -- Step 3: wave_out
        Timer(function()
            if self.Performer and isElement(self.Performer) then
                self.Performer:setAnimation("ON_LOOKERS", "wave_out", waveOutTime, false, false, false, false)
            end
        end, waveInTime + waveLoopTime, 1)

        if DEBUG then
            outputConsole("Wave:Apply (finite mode)")
        end

        OnGlobalActionFinished(totalDuration, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
            LookingBehavior.stopContinuousLooking(self.rotationTimer)
        end)
    end
end

--- Get dynamic string representation for serialization
--- @return string Lua code to recreate this action
function Wave:GetDynamicString()
    return 'return Wave{loop = ' .. tostring(self.loop) .. '}'
end
