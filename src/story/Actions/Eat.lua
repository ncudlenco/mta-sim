Eat = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts eating from it", " eats from it"})
    params.name = 'Eat'

    StoryActionBase.init(o, params)
    o.how = params.how or Eat.eHow.StandUp
end)

function Eat:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self, false, true, {"finishes", "finishes eating"})

    local setupTime = 3000
    local animBlock, animName

    if self.how == Eat.eHow.StandUp then
        animBlock = "VENDING"
        animName = "vend_eat1_P"
    elseif self.how == Eat.eHow.SitDown then
        animBlock = "INT_OFFICE"
        animName = "OFF_Sit_Drink"
    end

    -- Set animation to loop indefinitely
    setPedAnimation(self.Performer, animBlock, animName, -1, true, true, true, true)

    -- Capture actor-specific references to avoid conflicts when action instance is shared
    local performer = self.Performer
    local targetItem = self.TargetItem

    -- Clean up any existing timer for this performer
    local existingTimer = performer:getData('eatMonitorTimer')
    if existingTimer and isTimer(existingTimer) then
        killTimer(existingTimer)
    end

    -- Monitor action changes and cleanup when no longer eating
    local monitorTimer
    local me = self
    monitorTimer = Timer(function()
        if not performer or not isElement(performer) then
            if monitorTimer and isTimer(monitorTimer) then
                killTimer(monitorTimer)
            end
            performer:setData('eatMonitorTimer', nil)
            return
        end

        local currentAction = performer:getData('currentAction')
        if currentAction ~= 'Eat' then
            -- Action changed, cleanup food item
            if targetItem and targetItem.instance then
                detachElementFromBone(targetItem.instance)
                me:RemovePickedObject(performer)
                local pickedObjects = performer:getData('pickedObjects') or {}
                for i, value in ipairs(pickedObjects) do
                    if value[1] == targetItem.ObjectId then
                        table.remove(pickedObjects, i)
                        break
                    end
                end
                targetItem:Destroy()
                targetItem:Create()
            end

            if monitorTimer and isTimer(monitorTimer) then
                killTimer(monitorTimer)
            end
            performer:setData('eatMonitorTimer', nil)
            if DEBUG then
                print("Eat: Action changed, cleaned up food item")
            end
        end
    end, 200, 0)

    -- Store timer in performer metadata
    performer:setData('eatMonitorTimer', monitorTimer)

    if DEBUG then
        print("Eat:Apply")
    end

    OnGlobalActionFinished(setupTime, performer:getData('id'), performer:getData('storyId'))
end

function Eat:GetDynamicString()
    return 'return Eat{how = '..self.how..'}'
end

Eat.eHow = {
    SitDown = 1,
    StandUp = 2
}

function Eat:RemovePickedObject(actor)
    local pickedObjects = actor:getData('pickedObjects') or {}
    for i, value in ipairs(pickedObjects) do
        if value[1] == self.TargetItem.ObjectId then
            table.remove(pickedObjects, i)
            break
        end
    end
    actor:setData('pickedObjects', pickedObjects)
end