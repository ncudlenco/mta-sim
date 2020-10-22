AnswerPhone = class(StoryActionBase, function(o, params)
    params.description = " answers the "
    StoryActionBase.init(o, params)
end)

function AnswerPhone:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    -- this might not be ok
    if not self.TargetItem then
        self.TargetItem = MobilePhone {
            modelid = MobilePhone.eModel[PickRandom(MobilePhone.eModel)],
            position = Vector3(0,0,0),
            rotation = Vector3(0,0,0),
            noCollisions = true,
            interior = self.Performer.interior
        }
    end  
    
    self.TargetItem:Create()
    attachElementToBone(self.TargetItem.instance, self.Performer, 12, 
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)

    story.Logger:Log(self.Description .. self.TargetItem.Description, self)
    self.Performer:setAnimation("PED", "PHONE_IN", 2000, true, true, false, true)

    if DEBUG then
        outputConsole("AnswerPhone:Apply")
    end

    OnGlobalActionFinished(2000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function AnswerPhone:GetDynamicString()
    return 'return AnswerPhone{}'
end