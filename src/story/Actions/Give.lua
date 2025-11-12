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
                table.insert(pickedObjects, {self.TargetItem.ObjectId, self.TargetItem.Description})
                self.TargetPlayer:setData('pickedObjects', pickedObjects)
            end)
        end
    )
end

function Give:GetDynamicString()
    return 'return Give{hand = '..self.hand..', how = '..self.how..'}'
end