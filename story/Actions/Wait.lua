Wait = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" is waiting for something ", " is looking around "})
    params.name = 'Wait'

    StoryActionBase.init(o,params)
    o.Time = params.time
    o.doNothing = params.doNothing
end)

function Wait:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    StoryActionBase.GetLogger(self, story):Log(self.Description, self)

    self.Performer:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true) --TODO: do something smarter
    if DEBUG then
        outputConsole("Wait:Apply")
    end

    local function wait()
        if (math.abs((self.Performer.position - self.TargetItem.position).length) > 1) then
            self.Performer:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true) --TODO: do something smarter
            Timer(wait, 5000, 1)
        elseif not self.doNothing then
            OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
        end
    end
    wait()
end

function Wait:GetDynamicString()
    return 'return Wait{}'
end