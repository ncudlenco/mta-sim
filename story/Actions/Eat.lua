Eat = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is eating ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function Eat:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)

    math.randomseed(os.time())
    time = math.random(4000, 10000)
    setPedAnimation(self.Performer, "FOOD", "EAT_Burger", time, true, true, false, true)

    if DEBUG then
        outputConsole("Eat:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end