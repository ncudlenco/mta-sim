AnswerPhone = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " answers the ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function AnswerPhone:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    if not self.TargetItem then
        self.TargetItem = MobilePhone {
            modelid = MobilePhone.eModel.MobilePhone1,
            position = Vector3(0,0,0),
            rotation = Vector3(0,0,0),
            noCollisions = true,
            interior = self.Performer.interior
        }
        self.TargetItem:Create()
        attachElementToBone(self.TargetItem.instance, self.Performer, 12, 
                            self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                            self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)
    end    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation("PED", "PHONE_IN", 3000, true, true, false, true)
    --Create phone in hand and attach it

    if DEBUG then
        outputConsole("AnswerPhone:Apply")
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function AnswerPhone:GetDynamicString()
    return 'return AnswerPhone{}'
end