OpenLaptop = class(StoryActionBase, function(o, params)
    params.name = 'OpenLaptop'

    StoryActionBase.init(o,params)

    if o.TargetItem and o.TargetItem.type == 'Laptop' then
        o.Description = " opens the laptop lid "
    else
        o.Description = " powers on the PC "
    end
end)

function OpenLaptop:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self)
    if self.TargetItem and self.TargetItem.type == 'Laptop' then
        self.TargetItem:ChangeModel(Laptop.eModel.Open)
    end

    if DEBUG then
        outputConsole("OpenLaptop:Apply")
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function OpenLaptop:GetDynamicString()
    return 'return OpenLaptop{}'
end