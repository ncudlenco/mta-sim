BarbellWorkOut = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " works out with ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function BarbellWorkOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    math.randomseed(os.time())
    local time = math.random(8000, 18000)
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description .. ". When " .. self.Performer:getData('genderNominative') .. " finishes ", self.Performer)
    
    self.Performer:setAnimation("Freeweights", "gym_free_A", time, true, false, false, true)

    if DEBUG then
        outputConsole("BarbellWorkOut:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function BarbellWorkOut:GetDynamicString()
    return 'return BarbellWorkOut{}'
end