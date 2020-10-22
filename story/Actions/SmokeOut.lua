SmokeOut = class(StoryActionBase, function(o, params)
    params.description = " throws the "
    StoryActionBase.init(o,params)
end)

function SmokeOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Description .. self.TargetItem.Description .. " from  " .. self:getData('genderGenitive') 
                     ..  " hand when " .. self.Performer:getData('genderNominative') .. " finishes it", self.Performer)
    self.Performer:setAnimation("SMOKING", "M_smk_out", 3000, true, true, false, true)

    if DEBUG then
        outputConsole("SmokeOut:Apply")
    end

    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end

function SmokeOut:GetDynamicString()
    return 'return SmokeOut{}'
end