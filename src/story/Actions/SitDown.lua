SitDown = class(StoryActionBase, function(o, params)
    -- check mandatory options
    -- if type(params.performer) ~= "userdata" then
    --     error("SitDown: performer not given in the constructor")
    -- elseif type(params.targetItem) ~= "table" then
    --     error("SitDown: targetItem not given in the constructor")
    -- elseif type(params.nextLocation) ~= "table" then
    --     error("SitDown: nextLocation not given in the constructor")
    -- end
    params.description = " sits down"
    params.name = 'SitDown'

    StoryActionBase.init(o,params)
    o.how = params.how or SitDown.eHow.atDesk
    o.rotation= params.rotation or nil
end)

SitDown.eHow = {
    atDesk = 1,
    onSofa = 2
}

--- Polls the player's position and rotation until they match the target location or timeout is reached
-- @param performer The player element to check
-- @param targetPosition The target position Vector3
-- @param targetRotation The target rotation Vector3
-- @param animationLib The animation library to use when aligned
-- @param animationId The animation ID to use when aligned
-- @param elapsedTime Time elapsed since polling started (ms)
-- @param maxTimeout Maximum time to wait for alignment (ms)
local function waitForAlignment(performer, targetPosition, targetRotation, animationLib, animationId, elapsedTime, maxTimeout)
    if not performer or not isElement(performer) then
        if DEBUG then
            outputConsole("SitDown:waitForAlignment - Performer is invalid, aborting")
        end
        return
    end

    local positionTolerance = 0.05
    local rotationTolerance = 5.0 -- degrees

    -- Check position alignment
    local positionDiff = math.abs((performer.position - targetPosition).length)

    -- Check rotation alignment (Z-axis only, which controls horizontal orientation)
    local rotationDiff = math.abs(performer.rotation.z - targetRotation.z)
    -- Handle rotation wrapping (360 degrees = 0 degrees)
    if rotationDiff > 180 then
        rotationDiff = 360 - rotationDiff
    end

    local isPositionAligned = positionDiff < positionTolerance
    local isRotationAligned = rotationDiff < rotationTolerance
    local isAligned = isPositionAligned and isRotationAligned

    if DEBUG then
        outputConsole(string.format("SitDown:waitForAlignment - Position diff: %.4f (target: %.2f), Rotation diff: %.2f° (target: %.2f°), Elapsed: %dms",
            positionDiff, positionTolerance, rotationDiff, rotationTolerance, elapsedTime))
    end

    if isAligned or elapsedTime >= maxTimeout then
        if DEBUG then
            if isAligned then
                outputConsole("SitDown:waitForAlignment - Player aligned, starting animation")
            else
                outputConsole(string.format("SitDown:waitForAlignment - Timeout reached (%dms), starting animation anyway", elapsedTime))
            end
        end

        -- DEBUG TRACE: Log which actor ACTUALLY receives the animation
        local performerPos = performer.position
        local actorId = performer:getData('id')
        print(string.format("[MIDAIR_DEBUG][waitForAlignment] ANIMATION actorId=%s animLib=%s animId=%s",
            actorId, animationLib, animationId))
        if performerPos and targetPosition then
            print(string.format("[MIDAIR_DEBUG][waitForAlignment] actorId=%s performer.pos=(%.1f, %.1f, %.1f) target.pos=(%.1f, %.1f, %.1f)",
                actorId, performerPos.x, performerPos.y, performerPos.z,
                targetPosition.x, targetPosition.y, targetPosition.z))
            local dist = math.abs((performerPos - targetPosition).length)
            print(string.format("[MIDAIR_DEBUG][waitForAlignment] actorId=%s distance=%.2f", actorId, dist))
            if dist > 3.0 then
                print(string.format("[MIDAIR_DEBUG][waitForAlignment] WARNING: Actor %s is %.1f units from target - MID-AIR ANIMATION!", actorId, dist))
            end
        end

        -- Start the sitting animation
        performer:setAnimation(animationLib, animationId, -1, false, true, false, true)
    else
        -- Continue polling
        Timer(function()
            waitForAlignment(performer, targetPosition, targetRotation, animationLib, animationId, elapsedTime + 50, maxTimeout)
        end, 50, 1)
    end
end

function SitDown:Apply()
    local actorId = self.Performer:getData('id')
    local actorPos = self.Performer.position
    local actorLocationId = self.Performer:getData('locationId')
    local targetLocationId = self.NextLocation and self.NextLocation.LocationId or 'nil'

    -- DEBUG TRACE: Capture full state at SitDown execution
    print(string.format("[MIDAIR_DEBUG][SitDown:Apply] EXECUTING actorId=%s", actorId))
    print(string.format("[MIDAIR_DEBUG][SitDown:Apply] actorId=%s locationId=%s targetLocation=%s",
        actorId, tostring(actorLocationId), tostring(targetLocationId)))
    if actorPos then
        print(string.format("[MIDAIR_DEBUG][SitDown:Apply] actorId=%s position=(%.1f, %.1f, %.1f)",
            actorId, actorPos.x, actorPos.y, actorPos.z))
    end
    if self.TargetItem then
        local targetPos = self.TargetItem.instance and self.TargetItem.instance.position
        if targetPos then
            print(string.format("[MIDAIR_DEBUG][SitDown:Apply] actorId=%s targetItem.position=(%.1f, %.1f, %.1f)",
                actorId, targetPos.x, targetPos.y, targetPos.z))
            local dist = math.abs((actorPos - targetPos).length)
            print(string.format("[MIDAIR_DEBUG][SitDown:Apply] actorId=%s distance_to_target=%.2f", actorId, dist))
            if dist > 3.0 then
                print(string.format("[MIDAIR_DEBUG][SitDown:Apply] WARNING: Actor %s is %.1f units away from furniture - MID-AIR SIT DETECTED!", actorId, dist))
            end
        end
    else
        print(string.format("[MIDAIR_DEBUG][SitDown:Apply] WARNING: actorId=%s TargetItem is nil!", actorId))
    end

    local story = GetStory(self.Performer)
    table.insert(story.History[actorId], self)
    StoryActionBase.Apply(self)

    -- CRITICAL FIX: Capture performer before any Timers to prevent cross-actor contamination.
    -- Action instances are shared between actors. When another actor's action is planned,
    -- self.Performer gets overwritten. Capturing here ensures Timer closures use the correct actor.
    local performer = self.Performer

    local animationLib = "INT_OFFICE"
    local animationId = "OFF_Sit_In"
    local duration = 4000
    local initialDelay = 100 -- Initial delay before starting alignment polling

    -- Nil-safety: Check TargetItem before accessing properties to prevent silent crashes
    local targetDescription = self.TargetItem and self.TargetItem.Description or "unknown object"
    StoryActionBase.GetLogger(self, story):Log(self.Description .. " on the " .. targetDescription, self)

    if self.TargetItem and self.TargetItem.instance then
        self.TargetItem.instance:setCollisionsEnabled(false)
    elseif not self.TargetItem then
        print(string.format("[WARNING] SitDown:Apply - TargetItem is nil for actor %s, animation may be incorrect",
            self.Performer:getData('id')))
    end

    -- Disable collisions between this actor and all other peds while sitting
    triggerClientEvent("onDisablePedToPedCollisions", getRootElement(), self.Performer)

    -- Mark actor as on furniture to prevent displacement until StandUp
    self.Performer:setData('isOnFurniture', true)

    -- Set rotation first (if provided)
    if self.rotation then
        self.Performer.rotation = self.rotation
    end

    if self.how == SitDown.eHow.atDesk then
        animationLib = "INT_OFFICE"
        animationId = "OFF_Sit_In"
        duration = 4000
    elseif self.how == SitDown.eHow.onSofa then
        animationLib = "INT_HOUSE"
        animationId = "LOU_In"
        -- Allow rotation to settle in and adjust position
        Timer(function()
            if performer and isElement(performer) then
                performer.position = performer.position - performer.matrix.forward * 0.35
            end
        end, 100, 1)
        duration = 5000
        initialDelay = 150 -- Give extra time for sofa position adjustment
    end

    -- Wait for initial engine updates, then start polling for alignment
    Timer(function()
        if performer and isElement(performer) and self.NextLocation then
            if DEBUG then
                outputConsole("SitDown:Apply - Starting alignment polling")
            end
            waitForAlignment(
                performer,
                self.NextLocation.position,
                self.NextLocation.rotation,
                animationLib,
                animationId,
                0, -- elapsed time starts at 0
                1000 -- max timeout 1000ms
            )
        end
    end, initialDelay, 1)

    if DEBUG then
        outputConsole("SitDown:Apply")
    end

    -- CRITICAL: OnGlobalActionFinished MUST always be called to prevent deadlocks
    OnGlobalActionFinished(duration, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function SitDown:GetDynamicString()
    local rotationStr = nil
    if self.rotation then
        rotationStr = 'Vector3('..self.rotation.x..', '..self.rotation.y..', '..self.rotation.z..')'
    end
    return 'return SitDown{how = '..self.how..', rotation = '..(rotationStr or 'nil')..'}'
end