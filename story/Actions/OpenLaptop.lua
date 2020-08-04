OpenLaptop = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " opens the laptop lid ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function OpenLaptop:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description, self.Performer)
    self.TargetItem:ChangeModel(Laptop.eModel.Open)

    if DEBUG then
        outputConsole("OpenLaptop:Apply")
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function OpenLaptop:GetDynamicString()
    return 'return OpenLaptop{}'
end