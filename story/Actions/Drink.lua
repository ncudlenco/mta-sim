Drink = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts drinking from it", " drinks from it"})
    StoryActionBase.init(o, params)
end)

function Drink:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Description, self, false, true, {"finishes", "finishes drinking"})

    time = random(2000, 6000)
    setPedAnimation(self.Performer, "VENDING", "VEND_Drink2_P", time, true, true, false, true)

    if DEBUG then
        outputConsole("Drink:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Drink:GetDynamicString()
    return 'return Drink{}'
end