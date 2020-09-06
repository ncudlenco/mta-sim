Sleep = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " sleeps on it", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = params.how or Sleep.eHow.Left
end)

function Sleep:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. 
                     ". When " .. self.Performer:getData('genderNominative') .. " wakes up " .. self.Performer:getData('genderNominative'), self.Performer)
    -- self.TargetItem.instance:setCollisionsEnabled(false)
    self.Performer.rotation = self.Performer.rotation + Vector3(0,0,180)

    math.randomseed(os.time())
    local time = math.random(3, 8) * 1000
    if self.how == Sleep.eHow.Left then
        self.Performer:setAnimation("INT_HOUSE", "BED_Loop_L", time, true, true, false, true)
    elseif self.how == Sleep.eHow.Right then
        self.Performer:setAnimation("INT_HOUSE", "BED_Loop_R", time, true, true, false, true)
    end
    
    if DEBUG then
        outputConsole("Sleep:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Sleep:GetDynamicString()
    return 'return Sleep{how = '..self.how..'}'
end

Sleep.eHow = {
    Left = 1,
    Right = 2
}