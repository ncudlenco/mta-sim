StandUp = class(StoryActionBase, function(o, params)
    -- check mandatory options
    -- if type(params.performer) ~= "userdata" then
    --     error("StandUp: performer not given in the constructor")
    -- elseif type(params.targetItem) ~= "table" then
    --     error("StandUp: targetItem not given in the constructor")
    -- elseif type(params.nextLocation) ~= "table" then
    --     error("StandUp: nextLocation not given in the constructor")
    -- end
    params.description = " stands up "
    params.name = 'StandUp'

    StoryActionBase.init(o,params)
    o.how = params.how or StandUp.eHow.atDesk
end)

StandUp.eHow = {
    fromDesk = 1,
    fromSofa = 2
}

function StandUp:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. "from the " .. self.TargetItem.Description, self)
    if self.TargetItem.instance then
        self.TargetItem.instance:setCollisionsEnabled(false)
    end

    local animationLib = "INT_OFFICE"
    local animationId = "OFF_Sit_2Idle_180"
    local duration = 5000

    if self.how == StandUp.eHow.fromDesk then
        animationLib = "INT_OFFICE"
        animationId = "OFF_Sit_2Idle_180"
        duration = 5000
        -- Re-enable collisions between this actor and all other peds when standing up
        triggerClientEvent("onEnablePedToPedCollisions", getRootElement(), self.Performer)
    elseif self.how == StandUp.eHow.fromSofa then
        animationLib = "INT_HOUSE"
        animationId = "LOU_Out"
        self.Performer.rotation = self.Performer.rotation + Vector3(0,0,180)
        duration = 3000
    end

    -- Delay animation to allow rotation to be applied
    Timer(function()
        if self.Performer and isElement(self.Performer) then
            self.Performer:setAnimation(animationLib, animationId, duration, false, true, false, true)
        end
    end, 100, 1)
    if DEBUG then
        outputConsole("StandUp:Apply")
    end

    Timer(function()
        self.Performer.rotation = self.NextLocation.rotation
    end, duration + 200, 1)
    OnGlobalActionFinished(duration + 400, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function StandUp:GetDynamicString()
    return 'return StandUp{how = '..(self.how or 'nil')..'}'
end