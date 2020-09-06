Eat = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " eats it", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = params.how or Eat.eHow.StandUp
end)

function Eat:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. 
                    ". When " .. self.Performer:getData('genderNominative') .. " finishes eating " .. self.Performer:getData('genderNominative'), self.Performer)

    math.randomseed(os.time())
    time = math.random(5000, 10000)
    
    if self.how == Eat.eHow.StandUp then
        setPedAnimation(self.Performer, "VENDING", "vend_eat1_P", time, true, true, false, true)
    elseif self.how == Eat.eHow.SitDown then
        setPedAnimation(self.Performer, "INT_OFFICE", "OFF_Sit_Drink", time, true, true, false, true)
    end

    if DEBUG then
        outputConsole("Eat:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end

function Eat:GetDynamicString()
    return 'return Eat{how = '..self.how..'}'
end

Eat.eHow = {
    SitDown = 1,
    StandUp = 2
}