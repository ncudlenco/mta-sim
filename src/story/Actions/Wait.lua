Wait = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" is waiting for something ", " is looking around "})
    params.name = 'Wait'

    StoryActionBase.init(o,params)
    o.Time = params.time
    o.targetInteraction = params.targetInteraction
    o.doNothing = params.doNothing
    o.isLookingAtTarget = false
    o.lookAtTimer = nil
end)

function Wait:resume(player)
    if DEBUG then
        print('Wait.Resume actor '..tostring(player:getData('id'))..' enteredWaitingLoop '..tostring(player:getData('enteredWaitingLoop'))..' requestPause '..tostring(player:getData('requestPause'))..' paused '..tostring(player:getData('paused'))..' isReadyForInteraction '..tostring(player:getData('isReadyForInteraction'))..' isWaitingForInteraction '..tostring(player:getData('isWaitingForInteraction'))..' isAboutToInitiateInteraction '..tostring(player:getData('isAboutToInitiateInteraction')))
    end
    if player:getData('enteredWaitingLoop') then
        self:ExecuteWaitingLoop()
    elseif player:getData('isAboutToInitiateInteraction') then
        OnGlobalActionFinished(1, player:getData('id'), player:getData('storyId'))
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
        --Discard the z coordinate to handle the cases when actors located one next to each other are climbed on a table or another object.
        local distance = math.abs((Vector3(self.Performer.position.x, self.Performer.position.y, 0) - Vector3(self.TargetItem.position.x, self.TargetItem.position.y, 0)).length)
        local otherTargetLocation = self.TargetItem:getData('nextTargetLocation')
        local isOtherPlayerInTargetLocation = otherTargetLocation == self.NextLocation.LocationId
        local isOtherPlayerNearby = distance <= 1.5
        local isOtherPlayerWaitingForSameInteraction = self.TargetItem:getData("isWaitingForInteraction") == self.targetInteraction

        -- Determine if conditions are met for mutual gaze
        local shouldLookAtEachOther = isOtherPlayerNearby and
                                      isOtherPlayerInTargetLocation and
                                      isOtherPlayerWaitingForSameInteraction

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
            if not self.Performer:getData('requestPause') then
                Timer(wait, 5000, 1)
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
                if not self.Performer:getData('requestPause') then
                    Timer(wait, 5000, 1)
                end
            else
                -- Only the active actor gets here
                -- This actor in the next action will initiate the interaction
                -- CRITICAL: Stop continuous rotation before exiting to let next action take control
                LookingBehavior.stopContinuousLooking(self.Performer, self.lookAtTimer)
                self.lookAtTimer = nil
                self.isLookingAtTarget = false

                self.Performer:setData('enteredWaitingLoop', false)
                self.Performer:setData('isAboutToInitiateInteraction', true)
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

            self.Performer:setData('isReadyForInteraction', true)
            self.Performer:setData('enteredWaitingLoop', false)
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