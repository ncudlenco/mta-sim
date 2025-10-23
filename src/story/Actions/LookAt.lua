--- LookAt action - makes a ped look at an object, actor, or coordinates
--- Respects current ped state (sitting/lying) and only rotates body when standing
--- @param params table Constructor parameters
--- @param params.Target userdata|table|nil The target to look at (ped, object, or coordinates)
--- @param params.TargetCoordinates Vector3|nil Explicit coordinates to look at
LookAt = class(StoryActionBase, function(o, params)
    -- Build description based on target type
    local description = " is looking at "

    if params.Target then
        local targetType = isElement(params.Target) and params.Target:getType() or nil

        if targetType == "ped" or targetType == "player" then
            -- Target is an actor
            description = description .. params.Target:getData('name')
        elseif params.Target.Description then
            -- Target is an object
            description = description .. 'the ' .. params.Target.Description
        else
            description = description .. 'something'
        end
    elseif params.TargetCoordinates then
        description = description .. 'coordinates'
    else
        description = description .. 'something'
    end

    params.description = description
    params.name = 'LookAt'

    StoryActionBase.init(o, params)

    o.Target = params.Target
    o.TargetCoordinates = params.TargetCoordinates
    o.rotationTimer = nil  -- Will store the continuous rotation timer
end)

--- Helper function to check if the ped is in a seated or lying state
--- @param performer userdata The ped to check
--- @param story table The current story
--- @return boolean True if ped is seated/lying, false otherwise
local function isInSeatedOrLyingState(performer, story)
    local history = story.History[performer:getData('id')]
    if not history or #history == 0 then
        return false
    end

    -- Check the last action (current action is already added to history)
    -- We want to check the action before LookAt
    local previousActionIdx = #history - 1
    if previousActionIdx < 1 then
        return false
    end

    local lastAction = history[previousActionIdx]
    if not lastAction then
        return false
    end

    -- Check if last action was a seated/lying action
    local seatedActions = {
        "SitDown",
        "Sleep",
        "TypeOnKeyboard",
        "Read",
        "LookAtTheWatch",
        "OpenLaptop",
        "CloseLaptop",
        "PunchSeated",
        "LayOnElbow"
    }

    for _, actionName in ipairs(seatedActions) do
        if lastAction.Name == actionName then
            return true
        end
    end

    return false
end

--- Gets the current target position (updated dynamically for moving targets)
--- @return Vector3|nil The current target position or nil if target is invalid
function LookAt:GetTargetPosition()
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

function LookAt:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    -- Determine target position for logging
    local targetPosition = self:GetTargetPosition()
    local logDescription = self.Description

    if self.Target and isElement(self.Target) then
        local targetType = self.Target:getType()

        if targetType == "ped" or targetType == "player" then
            -- Target is an actor
            logDescription = " is looking at " .. self.Target:getData('name')
        elseif self.Target.Description then
            -- Target is an object
            logDescription = " is looking at the " .. self.Target.Description
        end
    elseif self.TargetCoordinates then
        logDescription = " is looking at coordinates"
    end

    StoryActionBase.GetLogger(self, story):Log(logDescription, self)

    -- Check if the performer is seated or lying down
    local isSeated = isInSeatedOrLyingState(self.Performer, story)

    if DEBUG then
        outputConsole("LookAt:Apply - isSeated: " .. tostring(isSeated))
    end

    -- Only rotate the ped if they are standing (not seated/lying)
    if targetPosition and not isSeated then
        if DEBUG then
            outputConsole("LookAt:Apply - Starting continuous rotation towards target")
        end

        -- Start continuous looking with body rotation and head tracking
        self.rotationTimer = LookingBehavior.startContinuousLooking(
            self.Performer,
            function() return self:GetTargetPosition() end,
            {
                expectedAction = 'LookAt',
                updateInterval = 200,
                skipBodyRotation = false,
                initialDelay = 500
            }
        )

    elseif isSeated and targetPosition then
        if DEBUG then
            outputConsole("LookAt:Apply - Ped is seated, preserving sitting state (body rotation disabled, head look only)")
        end

        -- Start continuous looking with head tracking only (no body rotation)
        self.rotationTimer = LookingBehavior.startContinuousLooking(
            self.Performer,
            function() return self:GetTargetPosition() end,
            {
                expectedAction = 'LookAt',
                updateInterval = 200,
                skipBodyRotation = true,
                initialDelay = 0
            }
        )
    end

    if DEBUG then
        outputConsole("LookAt:Apply")
    end

    -- Timer cleanup is handled automatically when currentAction changes
    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function LookAt:GetDynamicString()
    return 'return LookAt{}'
end

-- ============================================================================
-- CLIENT-SIDE CODE (runs on client only)
-- ============================================================================

if not triggerClientEvent then
    -- We're on the client side

    --- Client-side handler: Makes a ped look at specific coordinates using head tracking
    --- @param ped userdata The ped to make look
    --- @param x number|nil Target X coordinate (nil to reset)
    --- @param y number|nil Target Y coordinate
    --- @param z number|nil Target Z coordinate
    local function onPedLookAt(ped, x, y, z)
        if not isElement(ped) then
            return
        end

        if x and y and z then
            -- Make ped's head look at the target coordinates
            -- time parameter set to 3000ms for smooth head movement
            setPedLookAt(ped, x, y, z, 3000)
        else
            -- No coordinates provided - reset head to default position
            setPedLookAt(ped)
        end
    end

    -- Register client event handler
    addEvent("onPedLookAt", true)
    addEventHandler("onPedLookAt", root, onPedLookAt)
end
