SitDown = class(StoryActionBase, function(o, params)
    -- check mandatory options
    if type(params.performer) ~= "userdata" then
        error("SitDown: performer not given in the constructor")
    elseif type(params.targetItem) ~= "table" then
        error("SitDown: targetItem not given in the constructor")
    elseif type(params.nextLocation) ~= "table" then
        error("SitDown: nextLocation not given in the constructor")
    end
    StoryActionBase.init(o, " sits down ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = params.how or SitDown.eHow.atDesk
    o.rotation= params.rotation or Vector3(0, 0, 0)
end)

SitDown.eHow = {
    atDesk = 1,
    onSofa = 2
}

function SitDown:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. " on the " .. self.TargetItem.Description, self.Performer)
    self.TargetItem.instance:setCollisionsEnabled(false)

    self.Performer.rotation = self.rotation

    local animationLib = "INT_OFFICE"
    local animationId = "OFF_Sit_In"
    local duration = 5000
    if self.how == SitDown.eHow.atDesk then
        animationLib = "INT_OFFICE"
        animationId = "OFF_Sit_In"
        duration = 4000
    elseif self.how == SitDown.eHow.onSofa then
        animationLib = "INT_HOUSE"
        animationId = "LOU_In"
        self.Performer.position = self.Performer.matrix.position - self.Performer.matrix.forward * 0.6
        duration = 5000
    end

    self.Performer:setAnimation(animationLib, animationId, -1, false, true, false, true)
    if DEBUG then
        outputConsole("SitDown:Apply")
    end

    OnGlobalActionFinished(duration, self.Performer:getData('id'), self.Performer:getData('storyId'))
end