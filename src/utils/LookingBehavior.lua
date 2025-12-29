--- LookingBehavior utility module
-- Provides reusable functions for making peds look at targets with body rotation and head tracking.
-- Used by story actions like LookAt and Wait to implement looking behavior.
-- @module LookingBehavior

LookingBehavior = {}

--- Check if a number value is NaN (Not a Number)
-- @param value any The value to check
-- @return boolean True if the value is NaN, false otherwise
function LookingBehavior.isNaN(value)
    return type(value) == "number" and value ~= value
end

--- Rotate a ped's body to face towards a target position
-- Uses matrix calculations to determine the rotation angle and updates the ped's rotation.
-- @param performer userdata The ped element to rotate
-- @param targetPos Vector3 The position to face towards
-- @return boolean True if rotation was successful, false otherwise
function LookingBehavior.faceTowardsTarget(performer, targetPos)
    if not performer or not targetPos then
        if DEBUG then
            print("LookingBehavior.faceTowardsTarget: Invalid performer or targetPos")
        end
        return false
    end

    if not isElement(performer) or not performer.position then
        if DEBUG then
            print("LookingBehavior.faceTowardsTarget: Performer is not an element or has no position")
        end
        return false
    end

    local targetFront = targetPos - performer.position
    local angle = performer.matrix.forward:angleAboutAxis(targetFront, performer.matrix.up)

    -- NaN safety check using existing utility
    if LookingBehavior.isNaN(angle) then
        if DEBUG then
            print("LookingBehavior.faceTowardsTarget: Angle is NaN, skipping rotation")
        end
        return false
    end

    if DEBUG then
        print(string.format("LookingBehavior.faceTowardsTarget: performer=%s, currentRot=%.2f, angle=%.2f deg",
            tostring(performer:getData('id') or 'unknown'),
            performer.rotation.z,
            math.deg(angle)
        ))
    end

    performer.rotation = Vector3(0, 0, performer.rotation.z + math.deg(angle))

    if DEBUG then
        print(string.format("LookingBehavior.faceTowardsTarget: Set new rotation to %.2f", performer.rotation.z))
    end

    return true
end

--- Trigger client-side head tracking for a ped
-- Sends a client event to make the ped's head look at specific coordinates or target element.
-- If both targetPos and targetElement are nil, resets the head to default position.
-- @param performer userdata The ped element
-- @param targetPos Vector3|nil The position to look at, or nil to reset
-- @param targetElement userdata|nil Optional target ped/player element for direct tracking
function LookingBehavior.triggerHeadLook(performer, targetPos, targetElement)
    if not isElement(performer) then
        return
    end

    -- Priority 1: Use target element if it's a ped/player
    if targetElement and isElement(targetElement) then
        local targetType = getElementType(targetElement)
        if targetType == "ped" or targetType == "player" then
            triggerClientEvent(root, "onPedLookAt", root, performer, nil, nil, nil, targetElement)
            return
        end
    end

    -- Priority 2: Use position coordinates
    if targetPos and targetPos.x and targetPos.y and targetPos.z then
        triggerClientEvent(root, "onPedLookAt", root, performer, targetPos.x, targetPos.y, targetPos.z, nil)
    else
        -- Reset head tracking
        triggerClientEvent(root, "onPedLookAt", root, performer, nil, nil, nil, nil)
    end
end

--- Check if a performer is still valid for looking operations
-- Validates that the performer element exists, is alive, and optionally checks if a specific action is current.
-- @param performer userdata The ped element to check
-- @param expectedAction string|nil Optional action name to check against performer's currentAction
-- @return boolean True if performer is valid, false otherwise
function LookingBehavior.isPerformerValid(performer, expectedAction)
    if not performer or not isElement(performer) then
        return false
    end

    if performer:isDead() then
        return false
    end

    if expectedAction then
        local currentAction = performer:getData('currentAction')
        if currentAction ~= expectedAction then
            return false
        end
    end

    return true
end

--- Start continuous looking behavior with automatic rotation and head tracking updates
-- Creates a timer that continuously updates body rotation and head tracking towards a dynamic target.
-- The timer automatically cleans up when the performer becomes invalid or the action changes.
-- @param performer userdata The ped element to make look
-- @param getTargetPosFn function A function that returns the current target position (Vector3|nil)
-- @param options table Configuration options:
--   - expectedAction (string|nil): Action name to verify is still current
--   - updateInterval (number): Timer interval in milliseconds (default: 200)
--   - skipBodyRotation (boolean): If true, only updates head tracking without body rotation (default: false)
--   - initialDelay (number): Delay before first head look in milliseconds (default: 500 for body rotation, 0 for head-only)
--   - getTargetElementFn (function|nil): Optional function that returns target ped/player element for direct tracking
-- @return userdata|nil Timer handle, or nil if failed to start
function LookingBehavior.startContinuousLooking(performer, getTargetPosFn, options)
    if not performer or not getTargetPosFn then
        return nil
    end

    options = options or {}
    local expectedAction = options.expectedAction
    local updateInterval = options.updateInterval or 200
    local skipBodyRotation = options.skipBodyRotation or false
    local initialDelay = options.initialDelay or (skipBodyRotation and 0 or 500)
    local getTargetElementFn = options.getTargetElementFn

    -- Validate performer is valid before starting
    if not LookingBehavior.isPerformerValid(performer, expectedAction) then
        return nil
    end

    local rotationTimer = nil

    -- Initial setup: body rotation and delayed head look
    local initialTargetPos = getTargetPosFn()
    local initialTargetElement = getTargetElementFn and getTargetElementFn() or nil

    if initialTargetPos then
        -- Step 1: Initial body rotation (only if not skipping)
        if not skipBodyRotation then
            LookingBehavior.faceTowardsTarget(performer, initialTargetPos)
        end

        -- Step 2: Delayed head look to allow body rotation to complete
        if initialDelay > 0 then
            Timer(function()
                if LookingBehavior.isPerformerValid(performer, expectedAction) then
                    local currentTargetPos = getTargetPosFn()
                    local currentTargetElement = getTargetElementFn and getTargetElementFn() or nil
                    if currentTargetPos then
                        LookingBehavior.triggerHeadLook(performer, currentTargetPos, currentTargetElement)
                    end
                end
            end, initialDelay, 1)
        else
            -- Immediate head look
            LookingBehavior.triggerHeadLook(performer, initialTargetPos, initialTargetElement)
        end

        -- Step 3: Start continuous rotation timer
        rotationTimer = Timer(function()
            -- Check if performer is still valid
            if not LookingBehavior.isPerformerValid(performer, expectedAction) then
                if rotationTimer and isTimer(rotationTimer) then
                    killTimer(rotationTimer)
                    rotationTimer = nil
                    LookingBehavior.triggerHeadLook(performer, nil, nil) -- Reset head look
                    if DEBUG then
                        print("LookingBehavior: Timer stopped - performer invalid or action changed")
                    end
                end
                return
            end

            -- Get current target position and element
            local currentTargetPos = getTargetPosFn()
            local currentTargetElement = getTargetElementFn and getTargetElementFn() or nil

            if currentTargetPos then
                -- Update body rotation first (if not skipping)
                if not skipBodyRotation then
                    LookingBehavior.faceTowardsTarget(performer, currentTargetPos)

                    -- Then update head look after a small delay (let body turn first)
                    Timer(function()
                        if LookingBehavior.isPerformerValid(performer, expectedAction) then
                            LookingBehavior.triggerHeadLook(performer, currentTargetPos, currentTargetElement)
                        end
                    end, 100, 1)
                else
                    -- Head-only mode: update head look immediately
                    LookingBehavior.triggerHeadLook(performer, currentTargetPos, currentTargetElement)
                end
            else
                -- Target no longer valid, stop timer
                if rotationTimer and isTimer(rotationTimer) then
                    killTimer(rotationTimer)
                    rotationTimer = nil
                    LookingBehavior.triggerHeadLook(performer, nil, nil) -- Reset head look
                    if DEBUG then
                        print("LookingBehavior: Timer stopped - target invalid")
                    end
                end
            end
        end, updateInterval, 0) -- Repeat indefinitely
    end

    return rotationTimer
end

--- Stop continuous looking behavior and cleanup
-- Kills the rotation timer and resets client-side head tracking to default position.
-- @param performer userdata The ped element
-- @param timerHandle userdata|nil The timer handle returned by startContinuousLooking
function LookingBehavior.stopContinuousLooking(performer, timerHandle)
    if timerHandle and isTimer(timerHandle) then
        killTimer(timerHandle)
        if DEBUG then
            print("LookingBehavior: Manual timer cleanup")
        end
    end

    if performer and isElement(performer) then
        LookingBehavior.triggerHeadLook(performer, nil, nil) -- Reset head tracking
    end
end
