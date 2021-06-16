SmokeIn = class(StoryActionBase, function(o, params)
    params.description = " takes out "
    params.name = 'SmokeIn'

    StoryActionBase.init(o,params)
end)

function SmokeIn:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    if self.Performer:getData("currentRegionId") == story.CurrentEpisode.CurrentRegion.Id then
        story.Logger:Log(self.Description .. getWordPrefix(self.TargetItem.Description) .. " " .. self.TargetItem.Description .. " from " .. self.Performer:getData('genderGenitive') .. " pocket", self)
    end
    
    self.Performer:setAnimation("SMOKING", "M_smk_in", 3000, true, true, false, true)
    attachElementToBone(self.TargetItem.instance, self.Performer, 12, 
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)

    if DEBUG then
        outputConsole("SmokeIn:Apply")
    end

    OnGlobalActionFinished(3000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function SmokeIn:GetDynamicString()
    return 'return SmokeIn{}'
end