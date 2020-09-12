Smoke = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o, PickRandom({" smokes a ", " starts smoking a "}), params.performer, params.targetItem, params.nextLocation, params.prerequisites or {}, params.closingAction or nil, params.nextAction or nil)
end)

function Smoke:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History, self)
    
    math.randomseed(os.time())
    time = math.random(5000, 12000)
    story.Logger:Log(self.Performer:getData('skinDescription') .. self.Description .. self.TargetItem.Description, self.Performer)
    self.Performer:setAnimation("SMOKING", "M_smk_drag", time, true, true, false, true)

    if DEBUG then
        outputConsole("Smoke:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Smoke:GetDynamicString()
    return 'return Smoke{}'
end