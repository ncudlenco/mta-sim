BenchpressWorkOut = class(StoryActionBase, function(o, params)
    params.name = 'BenchpressWorkOut'
    params.description = " is working out with the "
    StoryActionBase.init(o, params)
    o.how = BenchpressWorkOut.eHow.Slow
end)

function BenchpressWorkOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    local time = random(7000, 18000)

    local initialPosition = self.TargetItem.position
    local initialRotation = self.TargetItem.rotation

    attachElementToBone(self.TargetItem.instance, self.Performer, 12,
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description .. ". When " .. self.Performer:getData('genderNominative') .. " finishes ", self.Performer)

    self.Performer:setAnimation("benchpress", self.how, time, true, false, false, true)

    if DEBUG then
        outputConsole("BenchpressWorkOut:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        setElementPosition(self.TargetItem.instance, initialPosition)
        setElementRotation(self.TargetItem.instance, initialRotation)
    end)
end

function BenchpressWorkOut:GetDynamicString()
    return 'return BenchpressWorkOut{}'
end

BenchpressWorkOut.eHow =
{
    Slow = "gym_bp_up_a",
    Normal = "gym_bp_up_b",
    Fast = "gym_bp_up_smooth"
}