Drink = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is drinking ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function Drink:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description2, self.Performer)

    math.randomseed(os.time())
    time = math.random(2000, 6000)
    setPedAnimation(self.Performer, "VENDING", "VEND_Drink2_P", time, true, true, false, true)

    if DEBUG then
        outputConsole("Drink:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end