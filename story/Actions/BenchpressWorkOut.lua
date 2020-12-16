BenchpressWorkOut = class(StoryActionBase, function(o, params)
<<<<<<< HEAD
    StoryActionBase.init(o, " working out with the ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = BenchpressWorkOut.eHow.Slow
=======
    params.description = " works out at the "
    StoryActionBase.init(o, params)
>>>>>>> mta
end)

function BenchpressWorkOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    math.randomseed(os.time())
    local time = math.random(8000, 18000)

    local initialPosition = self.TargetItem.position
    local initialRotation = self.TargetItem.rotation
    
    attachElementToBone(self.TargetItem.instance, self.Performer, 12, 
                        self.TargetItem.PosOffset.x, self.TargetItem.PosOffset.y, self.TargetItem.PosOffset.z,
                        self.TargetItem.RotOffset.x, self.TargetItem.RotOffset.y, self.TargetItem.RotOffset.z)

    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description .. ". When " .. self.Performer:getData('genderNominative') .. " finishes ", self.Performer)
    
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