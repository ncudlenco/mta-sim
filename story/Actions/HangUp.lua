HangUp = class(StoryActionBase, function(o, params)
    params.description = " hangs up"
    StoryActionBase.init(o, params)
end)

function HangUp:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description, self)
    end

    self.Performer:setAnimation("PED", "PHONE_OUT", 2000, true, true, false, true)

    if DEBUG then
        outputConsole("HangUp:Apply")
    end

    OnGlobalActionFinished(2000, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
        self.TargetItem:Create()
    end)
end

function HangUp:GetDynamicString()
    return 'return HangUp{}'
end