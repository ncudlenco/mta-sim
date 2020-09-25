PedalGymBike = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, PickRandom({" starts pedalling at the ", " pedals at the "}), params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = params.how or PedalGymBike.eHow.Normal
end)

function PedalGymBike:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    if self.how == PedalGymBike.eHow.Still then
        self.Description = " stands still on "
    elseif self.how == PedalGymBike.eHow.Slow then
        self.Description = " pedals slowly "
    elseif self.how == PedalGymBike.eHow.Normal then
        self.Description = " pedals "
    elseif self.how == PedalGymBike.eHow.Fast then
        self.Description = " pedals fast "
    elseif self.how == PedalGymBike.eHow.Faster then
        self.Description = " pedals very fast "
    end
        
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)

    math.randomseed(os.time())
    local time = math.random(8000, 15000)
    self.Performer:setAnimation("GYMNASIUM", self.how, time, true, false, false, true)

    if DEBUG then
        outputConsole("PedalGymBike:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        detachElementFromBone(self.TargetItem.instance)
        self.TargetItem:Destroy()
    end)
end

function PedalGymBike:GetDynamicString()
    return 'return PedalGymBike{how='..self.how..'}'
end

PedalGymBike.eHow = {
    Still = "gym_bike_slow",
    Slow = "gym_bike_slow",
    Normal = "gym_bike_pedal",
    Fast = "gym_bike_fast",
    Faster = "gym_bike_faster"
}