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
    StoryActionBase.Apply(self) --TODO: make this call for each action!!!!!!!!!!

    self.Performer:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true) --TODO: do something smarter
    if DEBUG then
        outputConsole("Wait:Apply")
    end

    local function wait()
        --Discard the z coordinate to handle the cases when actors located one next to each other are climbed on a table or another object.
        local distance = math.abs((Vector3(self.Performer.position.x, self.Performer.position.y, 0) - Vector3(self.TargetItem.position.x, self.TargetItem.position.y, 0)).length)
        if (distance > 1) then
            self.Performer:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true) --TODO: do something smarter
            print("WAIT AGAIN with distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance)
            Timer(wait, 5000, 1)
        elseif not self.doNothing then
            print("WAIT IS FINISHED with distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance)
            OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
        else
            print("WAIT IS FINISHED with do nothing and distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance)
        end
    end
    wait()
end

function Wait:GetDynamicString()
    local doNothingStr = 'false'
    if self.doNothing then
        doNothingStr = 'true'
    end
    return 'return Wait{ doNothing = '..doNothingStr..' }'
end