PedalGymBike = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts pedalling ", " pedals "})
    StoryActionBase.init(o,params)
    o.how = PedalGymBike.eHow[PickRandom(PedalGymBike.eHow)]
end)

function PedalGymBike:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    if self.how == PedalGymBike.eHow.Still then
        self.Description = " stands still "
    elseif self.how == PedalGymBike.eHow.Slow then
        self.Description = PickRandom({" starts pedalling slowly ", " pedals slowly "})
    elseif self.how == PedalGymBike.eHow.Normal then
        self.Description = PickRandom({" starts pedalling ", " pedals "})
    elseif self.how == PedalGymBike.eHow.Fast then
        self.Description = PickRandom({" starts pedalling fast ", " pedals fast "})
    elseif self.how == PedalGymBike.eHow.Faster then
        self.Description = PickRandom({" starts pedalling very fast ", " pedals very fast "})
    end
        
    story.Logger:Log(self.Description, self)

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
    Still = "gym_bike_still",
    Slow = "gym_bike_slow",
    Normal = "gym_bike_pedal",
    Fast = "gym_bike_fast",
    Faster = "gym_bike_faster"
}