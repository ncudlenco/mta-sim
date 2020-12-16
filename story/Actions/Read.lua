Read = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts reading ", " reads "})
    StoryActionBase.init(o,params)
end)

function Read:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    math.randomseed(os.time())
    local time = math.random(3000, 12000)
    story.Logger:Log(self.Description .. self.TargetItem.Description, self, false, true, {"finishes", "finishes drinking"})
    self.Performer:setAnimation("INT_OFFICE", "OFF_Sit_Read", time, true, true, false, true)

    if DEBUG then
        outputConsole("Read:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Read:GetDynamicString()
    return 'return Read{}'
end