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

            outputConsole("Swapping object from one player to the other...")
            -- Schedule object transfer from target to performer
            OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'), function()
                detachElementFromBone(self.TargetItem.instance)
                local pickedObjects = self.TargetPlayer:getData('pickedObjects')
                if type(pickedObjects) == 'boolean' or not pickedObjects then
                    pickedObjects = {}
                end
                pickedObjects = Where(pickedObjects, function(po) return po[1] ~= self.TargetItem.ObjectId end)
                self.TargetPlayer:setData('pickedObjects', pickedObjects)
            end)

            OnGlobalActionFinished(time+10, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
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
                table.insert(pickedObjects, {self.TargetItem.ObjectId, self.TargetItem.Description})
                self.Performer:setData('pickedObjects', pickedObjects)
            end)
        end
    )
end

function Receive:GetDynamicString()
    return 'return Receive{hand = '..self.hand..', how = '..self.how..'}'
end