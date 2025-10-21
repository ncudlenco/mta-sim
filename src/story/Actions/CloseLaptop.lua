CloseLaptop = class(StoryActionBase, function(o, params)
    params.description = " closes the laptop lid "
    params.name = 'CloseLaptop'

    StoryActionBase.init(o, params)

    if o.TargetItem and o.TargetItem.type == 'Laptop' then
        o.Description = " closes the laptop lid "
    else
        o.Description = " powers off the PC "
    end

end)

function CloseLaptop:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self)
    if self.TargetItem and self.TargetItem.type == 'Laptop' then
        self.TargetItem:ChangeModel(Laptop.eModel.Closed)
    end

    if DEBUG then
        outputConsole("CloseLaptop:Apply")
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function CloseLaptop:GetDynamicString()
    return 'return CloseLaptop{}'
end