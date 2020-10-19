PedalGymBike = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, PickRandom({" starts pedalling at the ", " pedals at the "}), params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = PedalGymBike.eHow[PickRandom(PedalGymBike.eHow)]
end)

function PedalGymBike:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)

    if self.how == PedalGymBike.eHow.Still then
        self.Description = " stands still on the"
    elseif self.how == PedalGymBike.eHow.Slow then
        self.Description = PickRandom({" starts pedalling slowly at the ", " pedals slowly at the "})
    elseif self.how == PedalGymBike.eHow.Normal then
        self.Description = PickRandom({" starts pedalling at the ", " pedals at the "})
    elseif self.how == PedalGymBike.eHow.Fast then
        self.Description = PickRandom({" starts pedalling fast at the ", " pedals fast at the "})
    elseif self.how == PedalGymBike.eHow.Faster then
        self.Description = PickRandom({" starts pedalling very fast at the ", " pedals very fast at the "})
    end
        
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)

    math.randomseed(os.time())
    local time = math.random(8000, 15000)
    self.Performer:setAnimation("GYMNASIUM", self.how, time, true, false, false, true)

    if DEBUG then
        outputConsole("PedalGymBike:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function PedalGymBike:GetDynamicString()
    return 'return PedalGymBike{how=\"'..self.how..'\"}'
end

PedalGymBike.eHow = {
    Still = "gym_bike_slow",
    Slow = "gym_bike_slow",
    Normal = "gym_bike_pedal",
    Fast = "gym_bike_fast",
    Faster = "gym_bike_faster"
}