PutDown = class(StoryActionBase, function(o, params)
    params.description = " puts the "
    StoryActionBase.init(o,params)
    o.Where = params.where
    o.TargetObjectPosition = params.targetObjectPosition
    o.TargetObjectRotation = params.targetObjectRotation
    o.how = params.how or PickUp.eHow.Normal
end)

function PutDown:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Description .. self.TargetItem.Description .. " on " .. self.Where, self)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    local time = 500
    if self.how == PutDown.eHow.Normal then
        time = 200
        self.Performer:setAnimation("BAR", "Barserve_bottle", time, true, true, false, true)
    elseif self.how == PutDown.eHow.Down then
        self.Performer:setAnimation("MISC", "Case_pickup", time, true, true, false, true)
    elseif self.how == PutDown.eHow.FloorBarbell then
        self.Performer:setAnimation("Freeweights", "gym_free_putdown", time, true, true, false, true)
    end

    if DEBUG then
        outputConsole("PutDown:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
        -- setElementPosition(self.TargetItem.instance, self.TargetObjectPosition)
        -- setElementRotation(self.TargetItem.instance, self.TargetObjectRotation)
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