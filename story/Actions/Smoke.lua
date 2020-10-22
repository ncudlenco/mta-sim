Smoke = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" smokes a ", " starts smoking a "})
    StoryActionBase.init(o,params)
end)

function Smoke:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    math.randomseed(os.time())
    time = math.random(5000, 12000)
    story.Logger:Log(self.Description .. self.TargetItem.Description, self)
    self.Performer:setAnimation("SMOKING", "M_smk_drag", time, true, true, false, true)

    if DEBUG then
        outputConsole("Smoke:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Smoke:GetDynamicString()
    return 'return Smoke{}'
end