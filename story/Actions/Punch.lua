Punch = class(StoryActionBase, function(o, params)
    params.name = 'Punch'
    params.description = " is punching the "

    StoryActionBase.init(o, params)
    o.how = Punch.eHow[PickRandom(Punch.eHow)]
end)

function Punch:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)

    time = random(8000, 19000)

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