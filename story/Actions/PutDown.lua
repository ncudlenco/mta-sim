PutDown = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " puts ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.Where = params.where
    o.TargetObjectPosition = params.targetObjectPosition
    o.TargetObjectRotation = params.targetObjectRotation
    o.how = params.how or PickUp.eHow.Normal
end)

function PutDown:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description .. " on " .. self.Where, self.Performer)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    if self.how == PutDown.eHow.Normal then
        self.Performer:setAnimation("INT_SHOP", "shop_loop", 500, true, true, false, true)
    elseif self.how == PutDown.eHow.Down then
        self.Performer:setAnimation("MISC", "Case_pickup", 500, true, true, false, true)
    end

    if DEBUG then
        outputConsole("PutDown:Apply")
    end

    OnGlobalActionFinished(500, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
        setElementPosition(self.TargetItem.instance, self.TargetObjectPosition)
        setElementRotation(self.TargetItem.instance, self.TargetObjectRotation)
        self.TargetItem:Create()
    end)
end

PutDown.eHow = {
    Normal = 1,
    Down = 2
}