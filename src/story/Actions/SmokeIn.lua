SmokeIn = class(StoryActionBase, function(o, params)
    params.description = " prepares to smoke "
    params.name = 'SmokeIn'

    StoryActionBase.init(o,params)
end)

function SmokeIn:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    -- Object is already attached by TakeOut action
    StoryActionBase.GetLogger(self, story):Log(self.Description .. getWordPrefix(self.TargetItem.Description) .. " " .. self.TargetItem.Description, self)
    self.Performer:setAnimation("SMOKING", "M_smk_in", 3000, false, false, false, true)

    if DEBUG then
        outputConsole("SmokeIn:Apply")
    end

    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function SmokeIn:GetDynamicString()
    return 'return SmokeIn{}'
end