Punch = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " is punching the ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
    o.how = Punch.eHow[PickRandom(Punch.eHow)]
end)

function Punch:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)

    math.randomseed(os.time())
    time = math.random(8000, 15000)

    if self.how == Punch.eHow.Punch1 then
        block = "fight_b"
        animation = "fightb_1"
    elseif self.how == Punch.eHow.Punch2 then
        block = "fight_b"
        animation = "fightb_2"
    end

    self.Performer:setAnimation(block, animation, time, true, false, false, true)

    if DEBUG then
        outputConsole("Punch:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Punch:GetDynamicString()
    return 'return Punch{}'
end

Punch.eHow = {
    Punch1 = 1,
    Punch2 = 2,
}