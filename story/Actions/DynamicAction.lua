DynamicAction = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o,
        params.description,
        params.performer,
        params.targetItem,
        params.nextLocation,
        params.prerequisites or {},
        params.closingAction or nil,
        params.nextAction or nil
    )
    for k,v in pairs(params) do
        self[k] = v
    end
end)

function DynamicAction:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. " " ..self.Description, self.Performer)

    --Decide what to do based on what data is provided

    self.TargetItem:ChangeModel(Laptop.eModel.Closed)

    if DEBUG then
        outputConsole((self.name or "DynamicAction")..":Apply")
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end