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
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

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
            if self.Performer and isElement(self.Performer) then
                self.Performer.position = self.Performer.position - self.Performer.matrix.forward * 0.35
            end
        end, 100, 1)
        duration = 5000
        initialDelay = 150 -- Give extra time for sofa position adjustment
    end

    -- Wait for initial engine updates, then start polling for alignment
    Timer(function()
        if self.Performer and isElement(self.Performer) and self.NextLocation then
            if DEBUG then
                outputConsole("SitDown:Apply - Starting alignment polling")
            end
            waitForAlignment(
                self.Performer,
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