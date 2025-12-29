Drink = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts drinking from it", " drinks from it"})
    params.name = 'Drink'
    StoryActionBase.init(o, params)
end)

function Drink:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self, false, true, {"finishes", "finishes drinking"})

    local setupTime = 3000

    -- Set animation to loop indefinitely
    setPedAnimation(self.Performer, "VENDING", "VEND_Drink_P", -1, true, true, true, true)

    -- Capture actor-specific references to avoid conflicts when action instance is shared
    local performer = self.Performer

    -- Clean up any existing timer for this performer
    local existingTimer = performer:getData('drinkMonitorTimer')
    if existingTimer and isTimer(existingTimer) then
        killTimer(existingTimer)
    end

    -- Monitor action changes and cleanup when no longer drinking
    local monitorTimer
    monitorTimer = Timer(function()
        if not performer or not isElement(performer) then
            if monitorTimer and isTimer(monitorTimer) then
                killTimer(monitorTimer)
            end
            performer:setData('drinkMonitorTimer', nil)
            return
        end

        local currentAction = performer:getData('currentAction')
        if currentAction ~= 'Drink' then
            -- Action changed, cleanup is not needed for Drink
            if monitorTimer and isTimer(monitorTimer) then
                killTimer(monitorTimer)
            end
            performer:setData('drinkMonitorTimer', nil)
            if DEBUG then
                print("Drink: Action changed, stopping monitor")
            end
        end
    end, 200, 0)

    -- Store timer in performer metadata
    performer:setData('drinkMonitorTimer', monitorTimer)

    if DEBUG then
        print("Drink:Apply")
    end

    OnGlobalActionFinished(setupTime, performer:getData('id'), performer:getData('storyId'))
end

function Drink:GetDynamicString()
    return 'return Drink{}'
end