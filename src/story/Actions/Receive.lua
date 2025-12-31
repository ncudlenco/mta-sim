Receive = class(InteractionActionBase, function(o, params)
    params.description = " receives "
    params.name = 'Receive'
    params.interactionOffset = Vector3(-0.5, -0.5, 0)

    InteractionActionBase.init(o, params)

    o.how = params.how or PickUp.eHow.Normal
    o.hand = params.hand or PickUp.eHand.Left
end)

function Receive:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    -- -- Also add a Give action to TargetPlayer's history
    -- -- This ensures the second actor has the correct action name for event publication
    -- -- The Receive action is for history tracking only - the Receive action handles both actors
    -- local giveAction = Give {
    --     performer = self.TargetPlayer,
    --     targetPlayer = self.Performer,
    --     nextLocation = self.NextLocation,
    --     TargetItem = self.TargetItem,
    --     how = self.how,
    --     hand = self.hand
    -- }
    -- table.insert(story.History[self.TargetPlayer:getData('id')], giveAction)

    StoryActionBase.Apply(self)

    local time = 1000

    -- Synchronize actors: rotation → delay → position check → animations
    self:SyncActors(
        self.Performer,
        self.TargetPlayer,
        self.InteractionOffset,
        function()
            -- Actors are now properly positioned and facing each other
            StoryActionBase.GetLogger(self, story):Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

            outputConsole("Playing Receive animation...")
            self.Performer:setAnimation("gangs", "hndshkfa_swt", time, false, false, false, false)
            self.TargetPlayer:setAnimation("gangs", "hndshkfa_swt", time, false, false, false, false)

            if DEBUG then
                outputConsole("Receive:Apply")
            end

            local pickedUpObjectId = self.TargetPlayer:getData('pickedObjects')[1][1]
            local object = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Objects, function(o) return o.ObjectId == pickedUpObjectId end)
            if not object then
                error('Could not find object '..(pickedUpObjectId or 'null_object')..' that '..self.Performer:getData('id')..' would receive from '..self.TargetPlayer:getData('id'))
            end

            self.TargetItem = object

            -- Capture original chainId and locationId from giver's pickedObjects BEFORE removal
            local originalChainId = nil
            local originalLocationId = nil
            local giverPickedObjects = self.TargetPlayer:getData('pickedObjects') or {}
            for _, po in ipairs(giverPickedObjects) do
                if po[1] == self.TargetItem.ObjectId then
                    originalChainId = po[3]
                    originalLocationId = po[4]
                    break
                end
            end

            outputConsole("Swapping object from one player to the other...")

            if DEBUG then
                print("[DEBUG Receive] Scheduling OnGlobalActionFinished for TargetPlayer (giver): " .. self.TargetPlayer:getData('id') .. " at delay: " .. time)
            end

            -- Schedule object transfer from target to performer
            OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'), function()
                if DEBUG then
                    print("[DEBUG Receive] TargetPlayer callback executing - removing object from " .. self.TargetPlayer:getData('id'))
                end
                detachElementFromBone(self.TargetItem.instance)
                local pickedObjects = self.TargetPlayer:getData('pickedObjects')
                if type(pickedObjects) == 'boolean' or not pickedObjects then
                    pickedObjects = {}
                end
                pickedObjects = Where(pickedObjects, function(po) return po[1] ~= self.TargetItem.ObjectId end)
                self.TargetPlayer:setData('pickedObjects', pickedObjects)

                -- Clear giver's chain (giver no longer owns this object)
                self.TargetPlayer:setData('mappedChainId', nil)
                if DEBUG then
                    print("[Receive] Cleared mappedChainId for giver " .. self.TargetPlayer:getData('id'))
                end

                if DEBUG then
                    print("[DEBUG Receive] TargetPlayer callback completed - object removed")
                end
            end)

            if DEBUG then
                print("[DEBUG Receive] Scheduling OnGlobalActionFinished for Performer (receiver): " .. self.Performer:getData('id') .. " at delay: " .. (time+10))
            end

            OnGlobalActionFinished(time+10, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
                if DEBUG then
                    print("[DEBUG Receive] Performer callback executing - adding object to " .. self.Performer:getData('id'))
                    print("[DEBUG Receive] Object to add: " .. tostring(self.TargetItem.ObjectId) .. " (" .. tostring(self.TargetItem.Description) .. ")")
                end

                if self.how == PickUp.eHow.Normal then
                    self.TargetItem:updatePositionOffsetStandUp()
                    self.TargetItem:updateRotOffsetStandUp()
                elseif self.how == PickUp.eHow.Sit then
                    self.TargetItem:updatePositionOffsetSitDown()
                    self.TargetItem:updateRotOffsetSitDown()
                end

                attachElementToBone(self.TargetItem.instance, self.Performer, self.hand,
                    self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                    self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z
                )

                local pickedObjects = self.Performer:getData('pickedObjects')
                if type(pickedObjects) == 'boolean' or not pickedObjects then
                    pickedObjects = {}
                end

                if DEBUG then
                    print("[DEBUG Receive] Performer pickedObjects before insert: count = " .. #pickedObjects)
                end

                -- Store original chainId and locationId with received object (from pickedObjects, not actor data)
                table.insert(pickedObjects, {self.TargetItem.ObjectId, self.TargetItem.Description, originalChainId, originalLocationId})

                if DEBUG then
                    print("[Receive] Player "..self.Performer:getData('id').." pickedObjects after receiving:", self.TargetItem.Description )
                    print("[DEBUG Receive] Performer pickedObjects after insert: count = " .. #pickedObjects)
                end

                self.Performer:setData('pickedObjects', pickedObjects)

                -- Transfer chainId to receiver so they can use it for PutDown
                self.Performer:setData('mappedChainId', originalChainId)
                if DEBUG then
                    print("[Receive] Transferred mappedChainId to receiver " .. self.Performer:getData('id') .. ": " .. tostring(originalChainId))
                end

                if DEBUG then
                    print("[DEBUG Receive] Performer callback completed - object added")
                end
            end)
        end
    )
end

function Receive:GetDynamicString()
    return 'return Receive{hand = '..self.hand..', how = '..self.how..'}'
end