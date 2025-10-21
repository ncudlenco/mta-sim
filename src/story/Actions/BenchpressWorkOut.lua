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

    local setupTime = 3000

    local initialPosition = self.TargetItem.position
    local initialRotation = self.TargetItem.rotation

    attachElementToBone(self.TargetItem.instance, self.Performer, 12,
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description, self.Performer)

    self.Performer:setAnimation("benchpress", self.how, -1, true, false, true, true)

    -- Store cleanup data for when action is interrupted by GetOff
    self.Performer:setData('benchpress_cleanup', {
        object = self.TargetItem.instance,
        position = initialPosition,
        rotation = initialRotation
    })

    if DEBUG then
        outputConsole("BenchpressWorkOut:Apply")
    end

    OnGlobalActionFinished(setupTime, self.Performer:getData('id'), self.Performer:getData('storyId'))
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