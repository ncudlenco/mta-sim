TaiChi = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, " starts doing tai chi ", params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function TaiChi:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description, self.Performer)
    self.Performer:setAnimation("PARK", "Tai_Chi_in", 3000, true, true, false, true)

    math.randomseed(os.time())
    time = math.random(8000, 15000)

    self.Performer:setAnimation("PARK", "Tai_Chi_Loop", time, true, true, false, true)

    if DEBUG then
        outputConsole("TaiChi:Apply")
    end

    OnGlobalActionFinished(3000 + time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TaiChi:GetDynamicString()
    return 'return TaiChi{}'
end