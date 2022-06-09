Give = class(StoryActionBase, function(o, params)
    params.description = " gives "
    params.name = 'Give'

    StoryActionBase.init(o,params)

    o.TargetPlayer = params.targetPlayer
    o.how = params.how or PickUp.eHow.Normal
    o.hand = params.hand or PickUp.eHand.Right
end)

function Give:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    StoryActionBase.Apply(self)
    
    local function faceP1ToP2(p1, p2)
        local targetFront = p2.position - p1.position
        local angle = p1.matrix.forward:angleAboutAxis(targetFront, p1.matrix.up)
        p1.rotation = Vector3(0,0,p1.rotation.z + math.deg(angle))
    end
    
    self.TargetPlayer.position = self.Performer.position + Vector3(-0.5,-0.5,0)

    outputConsole("Facing players one to the other...")
    faceP1ToP2(self.Performer, self.TargetPlayer)
    faceP1ToP2(self.TargetPlayer, self.Performer)

    local time = 1000
    StoryActionBase.GetLogger(self, story):Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

    outputConsole("Playing hanshake animation...")
    self.Performer:setAnimation("gangs", "hndshkfa_swt", time, true, false, false, false)
    self.TargetPlayer:setAnimation("gangs", "hndshkfa_swt", time, true, false, false, false)

    if DEBUG then
        outputConsole("Give:Apply")
    end

    outputConsole("Swapping object from one player to the other...")
-- Note to self: seems like waiting never finishes...
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

function Give:GetDynamicString()
    return 'return Give{hand = '..self.hand..', how = '..self.how..'}'
end