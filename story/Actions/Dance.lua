Dance = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " dances", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function Dance:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. 
                     ". When " .. self.Performer:getData('genderNominative') .. " finishes dancing " .. self.Performer:getData('genderNominative'), self.Performer)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    math.randomseed(os.time())
    time = math.random(4000, 10000)

    self.Performer:setAnimation("DANCING", "dance_loop", time, true, true, false, true)

    if DEBUG then
        outputConsole("Dance:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Dance:GetDynamicString()
    return 'return Dance{}'
end