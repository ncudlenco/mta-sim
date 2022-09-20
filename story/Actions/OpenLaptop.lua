OpenLaptop = class(StoryActionBase, function(o, params)
    params.description = " opens the laptop lid "
    params.name = 'OpenLaptop'

    StoryActionBase.init(o,params)
end)

function OpenLaptop:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self)
    self.TargetItem:ChangeModel(Laptop.eModel.Open)

    if DEBUG then
        outputConsole("OpenLaptop:Apply")
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function OpenLaptop:GetDynamicString()
    return 'return OpenLaptop{}'
end