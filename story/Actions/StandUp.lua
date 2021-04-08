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
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description .. "from the " .. self.TargetItem.Description, self)
    end
    self.TargetItem.instance:setCollisionsEnabled(false)
    local animationLib = "INT_OFFICE"
    local animationId = "OFF_Sit_2Idle_180"
    local duration = 5000

    if self.how == StandUp.eHow.fromDesk then
        animationLib = "INT_OFFICE"
        animationId = "OFF_Sit_2Idle_180"
        duration = 5000
    elseif self.how == StandUp.eHow.fromSofa then
        animationLib = "INT_HOUSE"
        animationId = "LOU_Out"
        self.Performer.rotation = self.Performer.rotation + Vector3(0,0,180)
        duration = 3000
    end

    self.Performer:setAnimation(animationLib, animationId, duration, false, true, false, true)
    if DEBUG then
        outputConsole("StandUp:Apply")
    end

    Timer(function()
        self.Performer.rotation = self.NextLocation.rotation
    end, duration, 1)
    OnGlobalActionFinished(duration, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function StandUp:GetDynamicString()
    return 'return StandUp{how = '..(self.how or 'nil')..'}'
end