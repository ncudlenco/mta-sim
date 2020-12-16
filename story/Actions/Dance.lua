Dance = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts dancing", " dances"})
    StoryActionBase.init(o, params)
end)

function Dance:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    
    story.Logger:Log(self.Description, self, false, true, {"finishes", "finishes dancing"})
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    math.randomseed(os.time())
    time = math.random(4000, 10000)

    self.Performer:setAnimation("DANCING", "dance_loop", time, true, true, false, true)

    if DEBUG then
        outputConsole("Dance:Apply")
    end

    OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Dance:GetDynamicString()
    return 'return Dance{}'
end