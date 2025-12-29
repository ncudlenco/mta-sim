--- InteractionActionBase class
--- Base class for all two-actor interaction actions (HandShake, Kiss, Hug, Give, Laugh, Receive).
--- Provides common synchronization logic for rotation, positioning, and animation timing.
--- Each subclass retains control over animation selection, timing, and specific positioning logic.
--- @class InteractionActionBase
InteractionActionBase = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, params)
    o.TargetPlayer = params.targetPlayer
    o.isInteraction = true
    o.InteractionOffset = params.interactionOffset or Vector3(-0.5, -0.5, 0)
end)

--- Applies rotation to face both actors towards each other
--- Uses LookingBehavior.faceTowardsTarget for reliable, validated rotation
--- @param performer userdata First actor
--- @param target userdata Second actor
--- @return boolean True if both rotations succeeded, false otherwise
function InteractionActionBase:FaceActorsToEachOther(performer, target)
    local success1 = LookingBehavior.faceTowardsTarget(performer, target.position)
    local success2 = LookingBehavior.faceTowardsTarget(target, performer.position)
    return success1 and success2
end

--- Verifies and corrects the offset distance between actors
--- If the distance is incorrect, repositions the target actor along the vector between them.
--- This ensures the interaction offset (e.g., -0.5 for handshake, -0.7 for kiss) is respected.
--- @param performer userdata First actor (reference point, position unchanged)
--- @param target userdata Second actor (will be repositioned if needed)
--- @param offset Vector3 The desired offset
--- @param threshold number Distance threshold for correction (default: 0.1)
--- @return boolean True if position was corrected, false if already correct
function InteractionActionBase:VerifyAndCorrectOffset(performer, target, offset, threshold)
    threshold = threshold or 0.1

    local currentVector = target.position - performer.position
    local currentDistance = currentVector.length
    local desiredDistance = offset.length

    if math.abs(currentDistance - desiredDistance) > threshold then
        -- Reposition target along the vector between them at the correct distance
        local direction = currentVector:getNormalized()
        target.position = performer.position + (direction * desiredDistance)

        if DEBUG then
            print(string.format("[Interaction] Corrected offset: was %.2f, now %.2f",
                  currentDistance, desiredDistance))
        end
        return true
    end

    return false
end

--- Synchronizes two actors for interaction with fixed delay approach
--- Execution flow:
--- 1. Rotates both actors to face each other (synchronous coordinate changes)
--- 2. Waits for visual rendering to catch up (fixed delay, default 150ms)
--- 3. Verifies and corrects offset positioning to ensure proper distance
--- 4. Executes callback (typically to start animations and schedule completion)
---
--- @param performer userdata First actor
--- @param target userdata Second actor
--- @param offset Vector3 The interaction offset
--- @param onSyncComplete function Callback to execute when synchronized (start animations here)
--- @param rotationDelay number Delay in ms for visual update (default: 150)
function InteractionActionBase:SyncActors(performer, target, offset, onSyncComplete, rotationDelay)
    rotationDelay = rotationDelay or 150

    -- Step 1: Apply rotation (synchronous coordinate changes)
    local rotationSuccess = self:FaceActorsToEachOther(performer, target)

    if not rotationSuccess then
        if DEBUG then
            print("[Interaction] Warning: Rotation failed for one or both actors")
        end
    end

    -- Step 2: Wait for visual rendering to catch up (game engine needs time to update models)
    Timer(function()
        -- Step 3: Verify and correct offset positioning
        self:VerifyAndCorrectOffset(performer, target, offset)

        -- Step 4: Execute callback (start animations, schedule action completion)
        onSyncComplete()
    end, rotationDelay, 1)
end
