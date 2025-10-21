TaiChi = class(StoryActionBase, function(o, params)
    params.description = " starts doing tai chi "
    params.name = 'TaiChi'

    StoryActionBase.init(o,params)
end)

function TaiChi:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self)
    self.Performer:setAnimation("PARK", "Tai_Chi_in", 3000, true, true, false, true)

    local loopTime = random(8000, 15000)

    -- Delay second animation until first completes
    Timer(function()
        if self.Performer and isElement(self.Performer) then
            self.Performer:setAnimation("PARK", "Tai_Chi_Loop", -1, true, true, false, true)
        end
    end, 3000, 1)

    if DEBUG then
        outputConsole("TaiChi:Apply")
    end

    OnGlobalActionFinished(3000 + loopTime, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TaiChi:GetDynamicString()
    return 'return TaiChi{}'
end