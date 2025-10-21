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
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. " on the " .. self.TargetItem.Description, self)
    if self.TargetItem.instance then
        self.TargetItem.instance:setCollisionsEnabled(false)
    end

    -- Set rotation first (if provided)
    if self.rotation then
        self.Performer.rotation = self.rotation
    end

    local animationLib = "INT_OFFICE"
    local animationId = "OFF_Sit_In"
    local duration = 4000

    if self.how == SitDown.eHow.atDesk then
        animationLib = "INT_OFFICE"
        animationId = "OFF_Sit_In"
        duration = 4000
    elseif self.how == SitDown.eHow.onSofa then
        animationLib = "INT_HOUSE"
        animationId = "LOU_In"

        -- Calculate forward vector from rotation instead of matrix
        local rotation = self.rotation or self.Performer.rotation
        local radians = math.rad(rotation.z)
        local forwardX = math.sin(radians)
        local forwardY = math.cos(radians)

        -- Apply position adjustment
        self.Performer.position = self.Performer.position - Vector3(forwardX, forwardY, 0) * 0.6
        duration = 5000
    end

    -- Delay animation to allow position/rotation to be applied (reduced from 1000ms to 100ms)
    Timer(function()
        if self.Performer and isElement(self.Performer) then
            self.Performer:setAnimation(animationLib, animationId, -1, false, true, false, true)
        end
    end, 100, 1)

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