Wait = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" is waiting for something ", " is looking around "})
    params.name = 'Wait'

    StoryActionBase.init(o,params)
    o.Time = params.time
    o.targetInteraction = params.targetInteraction
    o.doNothing = params.doNothing
    o.isLookingAtTarget = false
    o.lookAtTimer = nil
    o.waitTimer = nil
end)

function Wait:resume(player)
    if DEBUG then
        print('Wait.Resume actor '..tostring(player:getData('id'))..' enteredWaitingLoop '..tostring(player:getData('enteredWaitingLoop'))..' requestPause '..tostring(player:getData('requestPause'))..' paused '..tostring(player:getData('paused'))..' isReadyForInteraction '..tostring(player:getData('isReadyForInteraction'))..' isWaitingForInteraction '..tostring(player:getData('isWaitingForInteraction'))..' isAboutToInitiateInteraction '..tostring(player:getData('isAboutToInitiateInteraction')))
    end
    if player:getData('enteredWaitingLoop') then
        self:ExecuteWaitingLoop()
    elseif player:getData('isAboutToInitiateInteraction') then
        -- Already triggered the global action finished
        -- OnGlobalActionFinished(1, player:getData('id'), player:getData('storyId'))
    end
end

function Wait:pause(player)
    if DEBUG then
        print('Wait.Pause actor '..tostring(player:getData('id'))..' enteredWaitingLoop '..tostring(player:getData('enteredWaitingLoop'))..' requestPause '..tostring(player:getData('requestPause'))..' paused '..tostring(player:getData('paused'))..' isReadyForInteraction '..tostring(player:getData('isReadyForInteraction'))..' isWaitingForInteraction '..tostring(player:getData('isWaitingForInteraction'))..' isAboutToInitiateInteraction '..tostring(player:getData('isAboutToInitiateInteraction')))
    end

    -- Cleanup looking behavior when pausing
    if self.isLookingAtTarget then
        LookingBehavior.stopContinuousLooking(self.Performer, self.lookAtTimer)
        self.lookAtTimer = nil
        self.isLookingAtTarget = false
    end

    -- Kill wait timer when pausing
    if self.waitTimer and isTimer(self.waitTimer) then
        killTimer(self.waitTimer)
        self.waitTimer = nil
        if DEBUG then
            print('Wait.Pause: Killed wait timer for '..player:getData('id'))
        end
    end

    if player:getData('requestPause') and not player:getData('enteredWaitingLoop') and player:getData('isReadyForInteraction') then
        player:setData('requestPause', false)
        player:setData('paused', true)
    end
end

-- Something real shady is happening here... Leads to sync problems. Some POI are busy from the start and peds are in a waiting state.
function Wait:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self)
    StoryActionBase.Apply(self)

    self.Performer:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true) --TODO: do something smarter
    if DEBUG then
        outputConsole("Wait:Apply")
    end
    self.Performer:setData("isWaitingForInteraction", self.targetInteraction)
    self.Performer:setData('isReadyForInteraction', false)
    self.Performer:setData('isAboutToInitiateInteraction', false)

    self:ExecuteWaitingLoop()
end

function Wait:ExecuteWaitingLoop()
    self.Performer:setData('enteredWaitingLoop', true)

    local function wait()
        -- If both actors are executing Wait, they've already arrived at their POIs
        -- Only check if waiting for same interaction
        local isOtherPlayerWaitingForSameInteraction = self.TargetItem:getData("isWaitingForInteraction") == self.targetInteraction

        -- Keep these for debug logging only (not used in synchronization)
        local distance = (self.Performer.position - self.TargetItem.position).length
        local otherTargetLocation = self.TargetItem:getData('nextTargetLocation')

        -- Determine if conditions are met for mutual gaze
        local shouldLookAtEachOther = isOtherPlayerWaitingForSameInteraction

        -- Debug logging for Wait synchronization state
        if DEBUG and DEBUG_WAIT_SYNC then
            print(string.format("[Wait:Sync] Actor %s (%s) polling partner %s:",
                self.Performer:getData('id'),
                self.doNothing and "passive" or "active",
                self.TargetItem:getData('id')))
            print(string.format("  - Interaction: %s (partner=%s, expected=%s)",
                tostring(isOtherPlayerWaitingForSameInteraction),
                tostring(self.TargetItem:getData('isWaitingForInteraction') or 'nil'),
                tostring(self.targetInteraction)))
            print(string.format("  - Result: shouldLookAtEachOther=%s", tostring(shouldLookAtEachOther)))
        end

        -- When the other actor is not near the current actor, and the other actor is actually coming here to execute an interaction and the actor that does not initiate the interaction
        -- has already waited and is ready to be interacted with
        if not shouldLookAtEachOther
        then
            -- -- Stop looking if currently looking
            if self.isLookingAtTarget then
                LookingBehavior.stopContinuousLooking(self.Performer, self.lookAtTimer)
                self.lookAtTimer = nil
                self.isLookingAtTarget = false
            end

            self.Performer:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true) --TODO: do something smarter
            if DEBUG then
                print(self.Performer:getData('id')..": WAIT AGAIN with distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance..'. The other target location is '..(otherTargetLocation or 'nil')..' The other interaction is '..(self.TargetItem:getData('isWaitingForInteraction') or 'nil'))
            end
            -- Kill existing timer before scheduling new one to prevent stacking
            if self.waitTimer and isTimer(self.waitTimer) then
                killTimer(self.waitTimer)
                self.waitTimer = nil
            end
            if not self.Performer:getData('requestPause') then
                self.waitTimer = Timer(wait, 5000, 1)
            end
        elseif not self.doNothing then
            -- Start looking at each other if not already looking
            if not self.isLookingAtTarget then
                -- Start continuous looking at the other actor (with body rotation)
                self.lookAtTimer = LookingBehavior.startContinuousLooking(
                    self.Performer,
                    function()
                        return LookingBehavior.isPerformerValid(self.TargetItem)
                               and self.TargetItem.position
                               or nil
                    end,
                    { expectedAction = 'Wait', updateInterval = 200, skipBodyRotation = false }
                )

                self.isLookingAtTarget = true
            end

            if not self.TargetItem:getData('isReadyForInteraction') then
                if DEBUG then
                    print(self.Performer:getData('id')..": My WAIT IS FINISHED but the other is not ready for interaction. Distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance..'. The other target location is '..(otherTargetLocation or 'nil')..' The other interaction is '..(self.TargetItem:getData('isWaitingForInteraction') or 'nil'))
                end
                -- Kill existing timer before scheduling new one to prevent stacking
                if self.waitTimer and isTimer(self.waitTimer) then
                    killTimer(self.waitTimer)
                    self.waitTimer = nil
                end
                if not self.Performer:getData('requestPause') then
                    self.waitTimer = Timer(wait, 5000, 1)
                end
            else
                -- Only the active actor gets here
                -- This actor in the next action will initiate the interaction

                -- GUARD: Prevent duplicate OnGlobalActionFinished from already-queued timer callbacks
                -- Note: killTimer() doesn't stop in-progress callbacks, only prevents future ones
                if self.Performer:getData('isAboutToInitiateInteraction') then
                    if DEBUG then
                        print(self.Performer:getData('id')..": Already initiated interaction - ignoring stacked timer callback")
                    end
                    return
                end

                -- CRITICAL: Stop continuous rotation before exiting to let next action take control
                LookingBehavior.stopContinuousLooking(self.Performer, self.lookAtTimer)
                self.lookAtTimer = nil
                self.isLookingAtTarget = false

                -- Kill wait timer since we're exiting
                if self.waitTimer and isTimer(self.waitTimer) then
                    killTimer(self.waitTimer)
                    self.waitTimer = nil
                end

                self.Performer:setData('enteredWaitingLoop', false)
                self.Performer:setData('isWaitingForInteraction', nil)
                self.Performer:setData('isAboutToInitiateInteraction', true)
                -- Active actor clears target's wait flags too (prevents race condition)
                self.TargetItem:setData('isWaitingForInteraction', nil)
                self.TargetItem:setData('enteredWaitingLoop', false)
                -- Clear passive actor's currentAction so allReady check passes in ValidateAndExecuteGroup
                self.TargetItem:setData('currentAction', nil)
                if DEBUG then
                    print("[Wait] Cleared currentAction for passive actor " .. self.TargetItem:getData('id'))
                end
                if DEBUG then
                    print(self.Performer:getData('id')..": WAIT IS FINISHED with distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance..'. The other target location is '..(otherTargetLocation or 'nil')..' The other interaction is '..(self.TargetItem:getData('isWaitingForInteraction') or 'nil'))
                    print('Exiting waiting loop actor '..tostring(self.Performer:getData('id'))..' enteredWaitingLoop '..tostring(self.Performer:getData('enteredWaitingLoop'))..' requestPause '..tostring(self.Performer:getData('requestPause'))..' paused '..tostring(self.Performer:getData('paused'))..' isReadyForInteraction '..tostring(self.Performer:getData('isReadyForInteraction'))..' isWaitingForInteraction '..tostring(self.Performer:getData('isWaitingForInteraction'))..' isAboutToInitiateInteraction '..tostring(self.Performer:getData('isAboutToInitiateInteraction')))
                end
                OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
                return
            end
        else
            -- Only the passive actor gets here
            -- Start looking at each other if not already looking
            if not self.isLookingAtTarget then
                -- Start continuous looking at the other actor (with body rotation)
                self.lookAtTimer = LookingBehavior.startContinuousLooking(
                    self.Performer,
                    function()
                        return LookingBehavior.isPerformerValid(self.TargetItem)
                               and self.TargetItem.position
                               or nil
                    end,
                    { expectedAction = 'Wait', updateInterval = 200, skipBodyRotation = false }
                )

                self.isLookingAtTarget = true
            end

            -- Stop continuous rotation before setting ready for interaction
            LookingBehavior.stopContinuousLooking(self.Performer, self.lookAtTimer)
            self.lookAtTimer = nil
            self.isLookingAtTarget = false

            -- Kill wait timer since we're exiting
            if self.waitTimer and isTimer(self.waitTimer) then
                killTimer(self.waitTimer)
                self.waitTimer = nil
            end

            self.Performer:setData('isReadyForInteraction', true)
            self.Performer:setData('enteredWaitingLoop', false)
            -- Note: Active actor clears isWaitingForInteraction for both actors
            if DEBUG then
                print(self.Performer:getData('id')..": WAIT IS FINISHED with do nothing (next action is not called) distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance..'. The other target location is '..(otherTargetLocation or 'nil')..' The other interaction is '..(self.TargetItem:getData('isWaitingForInteraction') or 'nil'))
            end
        end
        if self.Performer:getData('requestPause') then
            self.Performer:setData('requestPause', false)
            self.Performer:setData('paused', true)
        end
        if DEBUG then
            print('Exiting waiting loop actor '..tostring(self.Performer:getData('id'))..' enteredWaitingLoop '..tostring(self.Performer:getData('enteredWaitingLoop'))..' requestPause '..tostring(self.Performer:getData('requestPause'))..' paused '..tostring(self.Performer:getData('paused'))..' isReadyForInteraction '..tostring(self.Performer:getData('isReadyForInteraction'))..' isWaitingForInteraction '..tostring(self.Performer:getData('isWaitingForInteraction'))..' isAboutToInitiateInteraction '..tostring(self.Performer:getData('isAboutToInitiateInteraction')))
        end
    end
    -- self.NextLocation.isBusy = false
    wait()
end

function Wait:GetDynamicString()
    local doNothingStr = 'false'
    if self.doNothing then
        doNothingStr = 'true'
    end
    return 'return Wait{ doNothing = '..doNothingStr..' }'
end