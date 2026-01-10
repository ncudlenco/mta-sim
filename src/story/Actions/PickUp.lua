PickUp = class(StoryActionBase, function(o, params)
    params.description = " picks up "
    params.name = 'PickUp'

    StoryActionBase.init(o,params)
    o.Where = params.where
    o.TargetObjectExists = params.targetObjectExists or true
    o.how = params.how or PickUp.eHow.Normal
    o.hand = params.hand or PickUp.eHand.Right
    o.updateOffets = true
end)

function PickUp:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if not self.TargetObjectExists then
        self.TargetItem:Create()
    end

    StoryActionBase.Apply(self)

    local pickedObjects = self.Performer:getData('pickedObjects') or {}

    if type(pickedObjects) == 'boolean' or not pickedObjects then
        pickedObjects = {}
    end

    sameDescription = false
    sameObject = false

    for i, value in ipairs(pickedObjects) do
        if value[1] == self.TargetItem.ObjectId then
            sameObject = true
        end

        if value[2] == self.TargetItem.Description then
            sameDescription = true
        end
    end

    if sameObject then
        StoryActionBase.GetLogger(self, story):Log(self.Description .. "the same ".. self.TargetItem.Description .. " from " .. self.Where, self)
    elseif sameDescription then
        StoryActionBase.GetLogger(self, story):Log(self.Description .. "another " .. self.TargetItem.Description .. " from " .. self.Where, self)
    else
        StoryActionBase.GetLogger(self, story):Log(self.Description .. getWordPrefix(self.TargetItem.Description) .. " " .. self.TargetItem.Description .. " from " .. self.Where, self)
    end

    local time = 500
    if self.how == PickUp.eHow.Normal then
        time = 200
        if self.updateOffets then
            self.TargetItem:updatePositionOffsetStandUp()
            self.TargetItem:updateRotOffsetStandUp()
        end
        self.Performer:setAnimation("BAR", "Barserve_bottle", time, false, false, false, true)
    elseif self.how == PickUp.eHow.Down then
        self.Performer:setAnimation("MISC", "Case_pickup", time, false, false, false, true)
    elseif self.how == PickUp.eHow.Sit then
        if self.updateOffets then
            self.TargetItem:updatePositionOffsetSitDown()
            self.TargetItem:updateRotOffsetSitDown()
        end
        self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Drink", time, false, false, false, true)
    elseif self.how == PickUp.eHow.FloorBarbell then
        time = 2500
        self.Performer:setAnimation("freeweights", "gym_free_pickup", time, false, false, false, true)
    end

    -- Store chainId and locationId with picked object for object-specific chain tracking
    local chainId = self.Performer:getData('mappedChainId')
    local locationId = self.NextLocation and self.NextLocation.LocationId or nil
    table.insert(pickedObjects, {self.TargetItem.ObjectId, self.TargetItem.Description, chainId, locationId})
    self.Performer:setData('pickedObjects', pickedObjects)

    -- Store NextLocation reference for use in callback (self may not be accessible)
    local pickupPOI = self.NextLocation
    local performerId = self.Performer:getData('id')

    OnGlobalActionFinished(time, performerId, self.Performer:getData('storyId'), function()
        attachElementToBone(self.TargetItem.instance, self.Performer, self.hand,
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)

        -- FIX Issue 4: Mark the POI's object as taken to prevent other actors from picking it up
        -- This prevents the "drink hijacking" bug where a displaced actor loses their drink
        -- to another actor who picks up from the same POI
        if pickupPOI then
            pickupPOI:setData('objectTakenByActor', performerId)
            if DEBUG then
                print("[PickUp] Marked POI "..pickupPOI.LocationId.." object as taken by "..performerId)
            end
        end
    end)

end

function PickUp:GetDynamicString()
    return 'return PickUp{where = "'..self.Where..'", targetObjectExists = '.. tostring(self.TargetObjectExists) ..', hand = '..self.hand..', how = '..self.how..'}'
end

PickUp.eHow = {
    Normal = 1,
    Down = 2,
    Sit = 3,
    FloorBarbell = 4
}

PickUp.eHand = {
    Left = 11,
    Right = 12
}