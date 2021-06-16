SitDown = class(StoryActionBase, function(o, params)
    -- check mandatory options
    -- if type(params.performer) ~= "userdata" then
    --     error("SitDown: performer not given in the constructor")
    -- elseif type(params.targetItem) ~= "table" then
    --     error("SitDown: targetItem not given in the constructor")
    -- elseif type(params.nextLocation) ~= "table" then
    --     error("SitDown: nextLocation not given in the constructor")
    -- end
    params.description = " sits down"
    params.name = 'SitDown'

    StoryActionBase.init(o,params)
    o.how = params.how or SitDown.eHow.atDesk
    o.rotation= params.rotation or nil
end)

SitDown.eHow = {
    atDesk = 1,
    onSofa = 2
}

function SitDown:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description .. " on the " .. self.TargetItem.Description, self)
    end
    
    self.TargetItem.instance:setCollisionsEnabled(false)

    if not (self.rotation == nil) then
        self.Performer.rotation = self.rotation
    end

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

function SitDown:GetDynamicString()
    local rotationStr = nil
    if self.rotation then
        rotationStr = 'Vector3('..self.rotation.x..', '..self.rotation.y..', '..self.rotation.z..')'
    end
    return 'return SitDown{how = '..self.how..', rotation = '..(rotationStr or 'nil')..'}'
end