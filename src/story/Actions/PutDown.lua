PutDown = class(StoryActionBase, function(o, params)
    params.description = " puts the "
    params.name = 'PutDown'

    StoryActionBase.init(o,params)
    o.Where = params.where
    o.TargetObjectPosition = params.targetObjectPosition
    o.TargetObjectRotation = params.targetObjectRotation
    o.how = params.how or PutDown.eHow.Normal
end)

function PutDown:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    StoryActionBase.Apply(self)
    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description .. " on " .. self.Where, self)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    -- Remove from inventory IMMEDIATELY so subsequent event planning sees correct state
    self:RemovePickedObject()

    local time = 500
    if self.how == PutDown.eHow.Normal then
        time = 200
        self.Performer:setAnimation("BAR", "Barserve_bottle", time, false, false, false, true)
    elseif self.how == PutDown.eHow.Down then
        self.Performer:setAnimation("MISC", "Case_pickup", time, false, false, false, true)
    elseif self.how == PutDown.eHow.FloorBarbell then
        time = 1000
        self.Performer:setAnimation("Freeweights", "gym_free_putdown", time, false, false, false, true)
    end

    if DEBUG then
        outputConsole("PutDown:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
        self.TargetItem:Create()
    end)
end

PutDown.eHow = {
    Normal = 1,
    Down = 2,
    FloorBarbell = 3
}

function PutDown:GetDynamicString()
    return 'return PutDown{where = "'..self.Where..'", how = '..self.how..'}'
end

function PutDown:RemovePickedObject()
    local pickedObjects = self.Performer:getData('pickedObjects') or {}
    local targetObjectId = self.TargetItem and self.TargetItem.ObjectId or "nil"
    local targetDescription = self.TargetItem and self.TargetItem.Description or "nil"

    if DEBUG then
        print(string.format("[RemovePickedObject] Looking for ObjectId=%s, Description=%s",
            tostring(targetObjectId), tostring(targetDescription)))
        print(string.format("[RemovePickedObject] pickedObjects count: %d", #pickedObjects))
        for idx, value in ipairs(pickedObjects) do
            print(string.format("[RemovePickedObject]   [%d] ObjectId=%s, Description=%s",
                idx, tostring(value[1]), tostring(value[2])))
        end
    end

    local found = false
    for i, value in ipairs(pickedObjects) do
        if value[1] == self.TargetItem.ObjectId then
            table.remove(pickedObjects, i)
            found = true
            if DEBUG then
                print("[RemovePickedObject] Found and removed by ObjectId")
            end
            break
        end
    end

    if DEBUG and not found then
        print("[RemovePickedObject] WARNING: No matching ObjectId found!")
    end

    self.Performer:setData('pickedObjects', pickedObjects)
end