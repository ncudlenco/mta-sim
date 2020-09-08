SmokeIn = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " takes out ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function SmokeIn:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. getWordPrefix(self.TargetItem.Description) .. " " .. self.TargetItem.Description .. " from " .. self.Performer:getData('genderGenitive') .. " pocket", self.Performer)
    self.Performer:setAnimation("SMOKING", "M_smk_in", 3000, true, true, false, true)
    self.TargetItem:Create()
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