SmokeOut = class(StoryActionBase, function(o, params)
    params.description = " throws away the "
    params.name = 'SmokeOut'

    StoryActionBase.init(o,params)
end)

function SmokeOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation("SMOKING", "M_smk_out", 3000, true, true, false, true)

    if DEBUG then
        outputConsole("SmokeOut:Apply")
    end

    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
        self.TargetItem:Create()
    end)
end

function SmokeOut:GetDynamicString()
    return 'return SmokeOut{}'
end