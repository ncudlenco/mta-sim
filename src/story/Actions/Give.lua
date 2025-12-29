Give = class(InteractionActionBase, function(o, params)
    params.description = " gives "
    params.name = 'Give'
    params.interactionOffset = Vector3(-0.5, -0.5, 0)

    InteractionActionBase.init(o, params)

    o.how = params.how or PickUp.eHow.Normal
    o.hand = params.hand or PickUp.eHand.Right
end)

function Give:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    -- -- Also add a Receive action to TargetPlayer's history
    -- -- This ensures the second actor has the correct action name for event publication
    -- -- The Receive action is for history tracking only - the Give action handles both actors
    -- local receiveAction = Receive {
    --     performer = self.TargetPlayer,
    --     targetPlayer = self.Performer,
    --     nextLocation = self.NextLocation,
    --     TargetItem = self.TargetItem,
    --     how = self.how,
    --     hand = self.hand
    -- }
    -- table.insert(story.History[self.TargetPlayer:getData('id')], receiveAction)

    StoryActionBase.Apply(self)

    local time = 1000

    -- Synchronize actors: rotation → delay → position check → animations
    self:SyncActors(
        self.Performer,
        self.TargetPlayer,
        self.InteractionOffset,
        function()
            -- Look up the actual object from giver's pickedObjects (like Receive.lua does)
            -- This is needed because EventPlanner may incorrectly set targetItem to otherActor
            local giverPickedObjects = self.Performer:getData('pickedObjects') or {}
            if #giverPickedObjects > 0 then
                local pickedUpObjectId = giverPickedObjects[1][1]
                local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o)
                    return o.ObjectId == pickedUpObjectId
                end)
                if object then
                    self.TargetItem = object
                else
                    error('Could not find object '..(pickedUpObjectId or 'null_object')..
                          ' that '..self.Performer:getData('id')..' would give to '..
                          self.TargetPlayer:getData('id'))
                end
            end

            -- Capture original chainId and locationId from giver's pickedObjects BEFORE removal
            local originalChainId = nil
            local originalLocationId = nil
            for _, po in ipairs(giverPickedObjects) do
                if po[1] == self.TargetItem.ObjectId then
                    originalChainId = po[3]
                    originalLocationId = po[4]
                    break
                end
            end

            -- Actors are now properly positioned and facing each other
            StoryActionBase.GetLogger(self, story):Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

            outputConsole("Playing handshake animation...")
            self.Performer:setAnimation("gangs", "hndshkfa_swt", time, false, false, false, false)
            self.TargetPlayer:setAnimation("gangs", "hndshkfa_swt", time, false, false, false, false)

            if DEBUG then
                outputConsole("Give:Apply")
            end

            outputConsole("Swapping object from one player to the other...")
            -- Schedule object transfer from performer to target
            OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
                detachElementFromBone(self.TargetItem.instance)
                local pickedObjects = self.Performer:getData('pickedObjects')
                if type(pickedObjects) == 'boolean' then
                    pickedObjects = {}
                end
                pickedObjects = Where(pickedObjects, function(po) return po[1] ~= self.TargetItem.ObjectId end)
                self.Performer:setData('pickedObjects', pickedObjects)

                -- Clear giver's chain (giver no longer owns this object)
                self.Performer:setData('mappedChainId', nil)
                if DEBUG then
                    print("[Give] Cleared chain for giver " .. self.Performer:getData('id'))
                end
            end)

            OnGlobalActionFinished(time+10, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'), function()
                if self.how == PickUp.eHow.Normal then
                    self.TargetItem:updatePositionOffsetStandUp()
                    self.TargetItem:updateRotOffsetStandUp()
                elseif self.how == PickUp.eHow.Sit then
                    self.TargetItem:updatePositionOffsetSitDown()
                    self.TargetItem:updateRotOffsetSitDown()
                end

                attachElementToBone(self.TargetItem.instance, self.TargetPlayer, self.hand,
                    self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                    self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z
                )

                local pickedObjects = self.TargetPlayer:getData('pickedObjects')
                if type(pickedObjects) == 'boolean' then
                    pickedObjects = {}
                end
                -- Store original chainId and locationId with received object (from pickedObjects, not actor data)
                table.insert(pickedObjects, {self.TargetItem.ObjectId, self.TargetItem.Description, originalChainId, originalLocationId})
                if DEBUG then
                    print("[Give] Player "..self.TargetPlayer:getData('id').." pickedObjects after receiving:", self.TargetItem.Description )
                end
                self.TargetPlayer:setData('pickedObjects', pickedObjects)
            end)
        end
    )
end

function Give:GetDynamicString()
    return 'return Give{hand = '..self.hand..', how = '..self.how..'}'
end