CloseLaptop = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " closes the laptop lid ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function CloseLaptop:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description, self.Performer)
    self.TargetItem:ChangeModel(Laptop.eModel.Closed)

    if DEBUG then
        outputConsole("CloseLaptop:Apply")
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end