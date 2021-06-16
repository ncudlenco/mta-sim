Eat = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts eating from it", " eats from it"})
    params.name = 'Eat'

    StoryActionBase.init(o, params)
    o.how = params.how or Eat.eHow.StandUp
end)

function Eat:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Description, self, false, true, {"finishes", "finishes drinking"})

    time = random(5000, 14000)
    
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
        self.TargetItem:Create()
    end)
end

function Eat:GetDynamicString()
    return 'return Eat{how = '..self.how..'}'
end

Eat.eHow = {
    SitDown = 1,
    StandUp = 2
}